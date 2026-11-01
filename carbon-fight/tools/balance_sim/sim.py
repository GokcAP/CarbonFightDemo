"""CarbonFight hikaye sürümü mantık simülasyonu (GameState + TurnManager'ın Python karşılığı).
Amaç: akış kilitleniyor mu, haritalar bitiyor mu, final kazanılabilir mi, denge kabaca nasıl."""
import random, sys

CFG = dict(start_carbon=50, start_temp=1.1, start_welfare=60, carbon_per_turn=5, welfare_per_turn=-4,
           carbon_baseline=30, temp_per_carbon=0.003, temp_min=1.0, carbon_max=100, welfare_max=100,
           temp_lose=2.0, hand_size=3, deck_copies=3, max_level=3, synergy=0.25, weak=2.0, resist=0.5,
           sac=3, burn=2, rage_per_turn=1, heal_thr=60, heal_per=4, rew_c=-10, rew_w=10, rew_t=-0.1,
           smoke_mult=0.5, dirty_c=3, tide_dmg=2, asph_loss=1, asph_temp=2.0,
           flame_layers=3, flame_mult=0.25, dive_mult=2.0, heat_mult=0.5, vuln_turns=2, vuln_mult=2.0, reheat=3,
           ash_start=10, ash_max=20, ash_turn=1, ash_shard=-4, ash_lost=2, ash_sac=3, ash_div=4, ash_guard=1,
           su_armor=1, toprak_welfare=-2, gunes_ap=2)
CARDS = {  # id: (element, ap, hp, armor, carbon, welfare)
    'gunes_tarlasi': ('gunes', 4, 5, 0, -6, -1), 'dikey_tarim': ('toprak', 2, 7, 1, 1, 6),
    'mavi_karbon': ('su', 3, 6, 1, -4, 0), 'yesil_cati': ('toprak', 1, 9, 2, -2, 2),
    'toplu_tasima': ('gunes', 3, 6, 0, -3, 2), 'komur_santrali': ('fosil', 7, 8, 1, 8, 9)}
# saldırı: (desen, hasar, yanma, kilit)  desen 0 tek 1 sıra 2 sütun 3 artı
BOSSES = {
    'termik': dict(hp=50, weak='su', res='fosil', mech='FLAME', atk=[(1, 2, 2, 0), (0, 5, 0, 0)]),
    'levi': dict(hp=70, weak='toprak', res='su', mech='DIVE', atk=[(2, 3, 0, 2), (0, 6, 0, 0)]),
    'golem': dict(hp=90, weak='gunes', res='toprak', mech='HEAT', atk=[(3, 3, 0, 0), (1, 2, 2, 0), (0, 6, 0, 1)]),
    'kul': dict(hp=1, weak='su', res='fosil', mech='ASH', atk=[(3, 2, 1, 0), (0, 4, 0, 0), (1, 2, 2, 0)]),
}
MAPS = [
    dict(name='Vadi', boss='termik', quest='CHIMNEYS', smoke=2, chimneys=[2, 3, 7], shard='su'),
    dict(name='Korfez', boss='levi', quest='TRASH', tide=2, start_trash=[0, 2, 4, 8], trash_goal=6, shard='toprak'),
    dict(name='Sehir', boss='golem', quest='GREEN', asphalt=[0, 2, 4, 6, 8], green_turns=2, shard='gunes'),
    dict(name='Orman', boss='kul', quest='ALTARS', smoke=1, rtrash=3, asphalt=[3, 5], altars=[0, 2, 7], seed=4, shard=''),
]
BOTC = 3.0  # botun karbona verdigi onem (dusuk = kömür sever)
SHARD_ORDER = ['su', 'toprak', 'gunes']


def nb(s):
    r, c = divmod(s, 3); out = []
    if r > 0: out.append(s - 3)
    if r < 2: out.append(s + 3)
    if c > 0: out.append(s - 1)
    if c < 2: out.append(s + 1)
    return out


def pattern(p, a):
    if p == 0: return [a]
    if p == 1: return [a // 3 * 3 + i for i in range(3)]
    if p == 2: return [i * 3 + a % 3 for i in range(3)]
    return [a] + nb(a)


class Inst:
    def __init__(self, cid, kind='N', dirty=False):
        self.id, self.kind, self.dirty, self.level = cid, kind, dirty, 1
        if kind == 'N':
            self.el, self.ap0, self.hp0, self.armor, self.c, self.w = CARDS[cid]
        else:
            self.el = cid.split('_')[-1] if kind == 'S' else 'toprak'
            self.ap0, self.hp0, self.armor, self.c, self.w = 0, (8 if kind == 'S' else 99), 0, 0, 0
        self.hp = self.max_hp()
    def ap(self): return self.ap0 * self.level
    def max_hp(self): return self.hp0 * self.level


class Game:
    def __init__(self, seed=0, verbose=False):
        self.r = random.Random(seed); self.v = verbose
        self.carbon, self.temp, self.welfare = CFG['start_carbon'], CFG['start_temp'], CFG['start_welfare']
        self.turn = 1; self.shards = []; self.over = None; self.log_turns = []
        self.start_map(0)

    def log(self, *a):
        if self.v: print(f"[T{self.turn} {self.map['name']}]", *a)

    def start_map(self, i):
        self.mi = i; self.map = m = MAPS[i]; self.stage = 'REPAIR'; self.b = BOSSES[m['boss']]
        self.boss_hp = self.b['hp']; self.rage = 0; self.intent = None; self.islots = []
        self.flame = 0; self.diving = False; self.dcol = -1; self.exposed = 0; self.vuln = 0
        self.seed_given = False; self.calmed = set(); self.trash_cleaned = 0; self.tide_row = 0; self.mt = 0
        self.grid = [None] * 9; self.lock = [0] * 9; self.burnt = [0] * 9
        self.smoke = [0] * 9; self.trash = [0] * 9; self.asph = [0] * 9; self.green = [0] * 9; self.gp = [0] * 9
        self.hot = [0] * 9; self.altar = [''] * 9
        for s in m.get('chimneys', []): self.grid[s] = Inst('komur_santrali', dirty=True)
        for s in m.get('asphalt', []): self.asph[s] = 1
        for s in m.get('start_trash', []): self.trash[s] = 1
        for k, s in enumerate(m.get('altars', [])): self.altar[s] = SHARD_ORDER[k]
        self.deck = [c for c in CARDS for _ in range(CFG['deck_copies'])]; self.r.shuffle(self.deck); self.disc = []
        self.hand = []; self.map_start_turn = self.turn
        if m['quest'] == 'ALTARS':
            self.hand = [('S', 'shard_' + e) for e in SHARD_ORDER]; self.ash = CFG['ash_start']; self.wake()
        else:
            self.ash = 0
        self.roll_smoke(); self.start_turn()

    def draw(self):
        if not self.deck:
            self.deck, self.disc = self.disc, []; self.r.shuffle(self.deck)
        return ('N', self.deck.pop()) if self.deck else None

    def start_turn(self):
        self.played = False
        while len(self.hand) < CFG['hand_size']:
            c = self.draw()
            if not c: break
            self.hand.append(c)

    def has_shard(self, s): return self.grid[s] is not None and self.grid[s].kind == 'S'
    def on_altars(self): return sum(1 for s in range(9) if self.altar[s] and self.has_shard(s))

    def can_play_on(self, card, s):
        kind, cid = card
        if self.lock[s] or self.trash[s]: return False
        if kind == 'S': return self.altar[s] == cid.split('_')[1] and not self.has_shard(s)
        if kind == 'T': return s == self.map.get('seed', 4) and self.on_altars() >= 3
        return self.altar[s] == ''

    def is_merge(self, card, s):
        g = self.grid[s]; return card[0] == 'N' and g is not None and not g.dirty and g.id == card[1]

    def play(self, hi, s):
        card = self.hand.pop(hi); self.played = True; kind, cid = card; g = self.grid[s]
        if self.is_merge(card, s):
            g.level = min(g.level + 1, CFG['max_level']); g.hp = g.max_hp(); self.disc.append(cid)
            self.enter(s, g); self.check_quest(); return
        if g is not None and not g.dirty and g.kind == 'N': self.disc.append(g.id)
        inst = Inst(cid, {'N': 'N', 'S': 'S', 'T': 'T'}[kind]); self.grid[s] = inst; self.gp[s] = 0
        if kind == 'T':
            self.over = ('WIN', 'tohum'); return
        if kind == 'S':
            if cid not in self.calmed:  # düşüp geri konan parça öfkeyi yeniden azaltmaz
                self.calmed.add(cid)
                self.ash = max(0, min(CFG['ash_max'], self.ash + CFG['ash_shard']))
            if self.on_altars() >= 3 and not self.seed_given:
                self.seed_given = True; self.hand.append(('T', 'seed'))
        else:
            self.enter(s, inst)
        self.check_quest()

    def enter(self, s, inst):
        if True:
            if inst.el == 'toprak':
                for n in nb(s):
                    if self.trash[n]: self.trash[n] = 0; self.trash_cleaned += 1
            if self.stage == 'BOSS' and self.b['mech'] == 'HEAT':
                tg = ([s] + nb(s)) if self.green[s] else ([s] if inst.el == 'toprak' else [])
                cooled = [t for t in tg if self.hot[t]]
                for t in cooled: self.hot[t] = 0
                if cooled: self.update_heat()
            if self.stage == 'BOSS' and self.b['mech'] == 'DIVE' and self.diving and s % 3 == self.dcol:
                self.diving = False; self.exposed = 1

    def heat_armor(self): return sum(self.hot)

    def update_heat(self):
        if self.b['mech'] == 'HEAT' and self.heat_armor() == 0 and self.vuln == 0: self.vuln = CFG['vuln_turns']

    def quest(self):
        q = self.map['quest']
        if q == 'CHIMNEYS':
            left = sum(1 for g in self.grid if g and g.dirty); n = len(self.map['chimneys']); return n - left, n
        if q == 'TRASH': return min(self.trash_cleaned, self.map['trash_goal']), self.map['trash_goal']
        if q == 'GREEN': return sum(self.green), len(self.map['asphalt'])
        return self.on_altars(), 3

    def check_quest(self):
        if self.stage != 'REPAIR': return
        d, g = self.quest()
        if g > 0 and d >= g: self.log('ONARIM TAMAM'); self.wake()

    def wake(self):
        self.stage = 'BOSS'; self.boss_hp = self.b['hp']; self.rage = 0; self.wake_turn = self.turn
        if self.b['mech'] == 'FLAME': self.flame = CFG['flame_layers']
        if self.b['mech'] == 'HEAT':
            for i in range(9): self.hot[i] = 0 if self.green[i] else 1
        self.choose_intent()

    def choose_intent(self):
        if self.stage != 'BOSS': self.intent = None; self.islots = []; return
        self.intent = self.r.choice(self.b['atk'])
        pref = [i for i in range(9) if self.has_shard(i)] if self.b['mech'] == 'ASH' else []
        if not pref and self.b['mech'] == 'ASH': pref = [i for i in range(9) if self.altar[i]]
        if not pref: pref = [i for i in range(9) if self.grid[i]]
        a = self.r.choice(pref) if pref else self.r.randrange(9)
        self.islots = pattern(self.intent[0], a)

    def rage_bonus(self): return self.ash // CFG['ash_div'] if self.b['mech'] == 'ASH' else self.rage

    def elem_mult(self, e): return CFG['weak'] if e == self.b['weak'] else (CFG['resist'] if e == self.b['res'] else 1.0)
    def armor_bonus(self): return CFG['su_armor'] if 'su' in self.shards else 0
    def active(self, s): return self.grid[s] is not None and self.lock[s] == 0
    def can_attack(self, s): return self.active(s) and not self.grid[s].dirty and self.grid[s].kind == 'N'

    def card_ap(self, s):
        g = self.grid[s]; ap = g.ap()
        if g.el == 'gunes' and 'gunes' in self.shards: ap += CFG['gunes_ap']
        return ap

    def card_damage(self, s):
        g = self.grid[s]
        syn = 1 + CFG['synergy'] * sum(1 for n in nb(s) if self.can_attack(n) and self.grid[n].el == g.el)
        d = self.card_ap(s) * syn * self.elem_mult(g.el)
        if self.smoke[s]: d *= CFG['smoke_mult']
        return round(d)

    def hit_boss(self, raw, el):
        d = float(raw); m = self.b['mech']
        if m == 'FLAME' and self.flame > 0:
            if el == 'su': self.flame -= 1; return 0
            d *= CFG['flame_mult']
        elif m == 'DIVE':
            if self.diving: d = 0
            elif self.exposed > 0: d *= CFG['dive_mult']
        elif m == 'HEAT':
            if self.vuln > 0: d *= CFG['vuln_mult']
            elif self.heat_armor() > 0: d *= CFG['heat_mult']
        d = round(d); self.boss_hp = max(0, self.boss_hp - d); return d

    def damage_card(self, s, amt, ign=False):
        g = self.grid[s]
        if not g: return
        dealt = amt if ign else max(0, amt - g.armor - self.armor_bonus()); g.hp -= dealt
        if g.hp <= 0:
            self.grid[s] = None; self.gp[s] = 0
            if not g.dirty: self.disc.append(g.id)
            self.check_quest()

    def damage_shard(self, s, amt):
        g = self.grid[s]; guards = sum(1 for n in nb(s) if self.grid[n] and self.grid[n].kind == 'N' and not self.grid[n].dirty)
        g.hp -= max(0, amt - CFG['ash_guard'] * guards)
        if g.hp <= 0:
            self.grid[s] = None; self.hand.append(('S', g.id)); self.ash = min(CFG['ash_max'], self.ash + CFG['ash_lost'])
            self.log('PARÇA DÜŞTÜ', g.id)

    def stats(self, dc, dw, dt):
        self.carbon = max(0, min(CFG['carbon_max'], self.carbon + dc))
        self.welfare = max(0, min(CFG['welfare_max'], self.welfare + dw))
        self.temp = max(CFG['temp_min'], self.temp + dt)

    def roll_smoke(self):
        self.smoke = [0] * 9
        n = self.map.get('smoke', 0)
        c = [i for i in range(9) if not self.altar[i]]; self.r.shuffle(c)
        for i in c[:n]: self.smoke[i] = 1

    def tick_map(self):
        self.mt += 1; self.roll_smoke(); m = self.map
        if m.get('tide') and self.mt % m['tide'] == 0:
            row = self.tide_row; self.tide_row = (row + 1) % 3; dropped = 0
            for c in range(3):
                s = row * 3 + c
                if self.grid[s]:
                    if self.grid[s].kind == 'N': self.damage_card(s, CFG['tide_dmg'])
                elif not self.altar[s] and not self.trash[s]: self.trash[s] = 1; dropped += 1
            if dropped == 0 and m['quest'] == 'TRASH' and sum(self.trash) == 0:
                e = [i for i in range(9) if not self.grid[i] and not self.trash[i]]
                if e: self.trash[self.r.choice(e)] = 1
        if m.get('rtrash') and self.mt % m['rtrash'] == 0:
            e = [i for i in range(9) if not self.grid[i] and not self.trash[i] and not self.altar[i] and i != m.get('seed', 4)]
            if len(e) > 1: self.trash[self.r.choice(e)] = 1  # son boş slotu doldurma
        for i in range(9):
            if not self.asph[i]: continue
            g = self.grid[i]
            if not g or g.kind != 'N': self.gp[i] = 0; continue
            self.damage_card(i, CFG['asph_loss'], True)
            if not self.grid[i]: continue
            if g.el == 'toprak' and m['quest'] == 'GREEN':
                self.gp[i] += 1
                if self.gp[i] >= m['green_turns']:
                    self.asph[i] = 0; self.green[i] = 1; self.hot[i] = 0; self.gp[i] = 0
            else: self.gp[i] = 0
        self.check_quest()

    def tick_boss(self):
        if self.stage != 'BOSS': return
        m = self.b['mech']
        if m == 'DIVE':
            if self.exposed > 0: self.exposed -= 1
            elif self.diving: self.diving = False
            else: self.diving = True; self.dcol = self.r.randrange(3)
        elif m == 'HEAT':
            if self.vuln > 0:
                self.vuln -= 1
                if self.vuln == 0:
                    c = [i for i in range(9) if not self.green[i] and not self.hot[i]]; self.r.shuffle(c)
                    for i in c[:CFG['reheat']]: self.hot[i] = 1
        elif m == 'ASH':
            self.ash = min(CFG['ash_max'], self.ash + CFG['ash_turn'])
            if self.ash >= CFG['ash_max']: self.over = ('LOSE', 'öfke')

    def defeat(self):
        self.stats(CFG['rew_c'], CFG['rew_w'], CFG['rew_t'])
        if self.map['shard']: self.shards.append(self.map['shard'])
        self.log_turns.append((self.map['name'], self.wake_turn - self.map_start_turn, self.turn - self.wake_turn + 1,
                               round(self.temp, 2), self.welfare))
        self.log(f'BOSS YENİLDİ temp={self.temp:.2f} welfare={self.welfare}')
        self.turn += 1
        self.start_map(self.mi + 1)

    def end_turn(self):
        eco_c = eco_w = 0
        for i in range(9):
            if not self.active(i): continue
            g = self.grid[i]
            if g.dirty: eco_c += CFG['dirty_c']; continue
            if g.kind != 'N': continue
            if self.smoke[i] and g.el == 'gunes': continue
            eco_c += g.c; eco_w += g.w
        self.stats(eco_c, eco_w, 0)
        hit = []
        if self.stage == 'BOSS':
            if self.b['mech'] != 'ASH':
                for i in range(9):
                    if not self.can_attack(i): continue
                    self.hit_boss(self.card_damage(i), self.grid[i].el)
                    if self.boss_hp <= 0: self.defeat(); return
            if self.intent:
                p, dmg0, burn, lock = self.intent; dmg = dmg0 + self.rage_bonus()
                for s in self.islots:
                    hit.append(s); g = self.grid[s]
                    if g:
                        if g.kind == 'S': self.damage_shard(s, dmg)
                        elif g.kind == 'N': self.damage_card(s, dmg)
                    elif dmg > 0: self.stats(0, -dmg, 0)
                    self.burnt[s] = max(self.burnt[s], burn); self.lock[s] = max(self.lock[s], lock)
                    if self.b['mech'] == 'HEAT' and burn > 0 and not self.green[s]: self.hot[s] = 1
                if self.b['mech'] != 'ASH': self.rage += CFG['rage_per_turn']
            if self.b['mech'] != 'ASH':
                ex = self.carbon - CFG['heal_thr']
                if ex >= CFG['heal_per']: self.boss_hp = min(self.b['hp'], self.boss_hp + ex // CFG['heal_per'])
        self.tick_map()
        wd = CFG['toprak_welfare'] if 'toprak' in self.shards else CFG['welfare_per_turn']
        self.stats(CFG['carbon_per_turn'], wd, 0)
        dt = (self.carbon - CFG['carbon_baseline']) * CFG['temp_per_carbon']
        if dt > 0 and sum(self.asph) > 0 and self.map['quest'] == 'GREEN': dt *= CFG['asph_temp']
        self.stats(0, 0, dt)
        for i in range(9):
            if i in hit: continue
            if self.burnt[i] > 0:
                self.burnt[i] -= 1
                if self.grid[i] and self.grid[i].kind == 'N': self.damage_card(i, CFG['burn'], True)
            if self.lock[i] > 0: self.lock[i] -= 1
        if self.temp >= CFG['temp_lose']: self.over = ('LOSE', 'sıcaklık'); return
        if self.welfare <= 0: self.over = ('LOSE', 'refah'); return
        if self.b['mech'] == 'ASH' and self.ash >= CFG['ash_max']: self.over = ('LOSE', 'öfke'); return
        self.tick_boss()
        if self.over: return
        self.choose_intent(); self.turn += 1; self.start_turn()

    # ------------------------------------------------------------ bot
    def score_move(self, hi, s):
        kind, cid = self.hand[hi]
        if kind in ('S', 'T'): return 1000
        el, ap, hp, ar, c, w = CARDS[cid]; g = self.grid[s]; sc = 0.0
        q = self.map['quest']
        if self.stage == 'REPAIR':
            if q == 'CHIMNEYS' and g and g.dirty: sc += 100
            if q == 'TRASH' and el == 'toprak': sc += 60 * sum(self.trash[n] for n in nb(s))
            if q == 'GREEN' and self.asph[s] and el == 'toprak' and not g: sc += 80
            if q == 'GREEN' and self.asph[s] and el != 'toprak': sc -= 30
        else:
            sc += ap * self.elem_mult(el) * 3
            if self.b['mech'] == 'FLAME' and self.flame > 0 and el == 'su': sc += 40
            if self.b['mech'] == 'DIVE' and self.diving and s % 3 == self.dcol: sc += 50
            if self.b['mech'] == 'HEAT' and (self.green[s] and any(self.hot[t] for t in [s] + nb(s))): sc += 40
            if self.b['mech'] == 'ASH':
                sc += 30 * sum(1 for n in nb(s) if self.altar[n] and self.has_shard(n))
                sc += 10 * sum(1 for n in nb(s) if self.altar[n])
        if self.is_merge(self.hand[hi], s): sc += 25
        elif g is not None and not g.dirty: sc -= 20
        sc += -c * BOTC + w * 0.8
        if self.carbon > 70 and c > 0: sc -= 30
        if self.welfare < 25: sc += w * 3
        if s in self.islots: sc -= 8
        if self.asph[s] and el != 'toprak': sc -= 5
        return sc

    def bot_turn(self):
        best = None
        for hi in range(len(self.hand)):
            for s in range(9):
                if self.can_play_on(self.hand[hi], s):
                    sc = self.score_move(hi, s)
                    if best is None or sc > best[0]: best = (sc, hi, s)
        if best:
            self.play(best[1], best[2])
        if not self.over: self.end_turn()


def run(seed, verbose=False):
    g = Game(seed, verbose)
    while not g.over and g.turn < 200:
        g.bot_turn()
    return g


if __name__ == "__main__":
    if len(sys.argv) > 1:
        g = run(int(sys.argv[1]), True); print(g.over, g.turn, g.log_turns); sys.exit()
    res = {}; maps_reached = [0] * 5; turns = []; per_map = {}
    N = 300
    for sd in range(N):
        g = run(sd)
        key = g.over[0] + ':' + g.over[1] if g.over else 'TIMEOUT'
        res[key] = res.get(key, 0) + 1
        maps_reached[g.mi] += 1
        turns.append(g.turn)
        for name, rep, boss, t, w in g.log_turns:
            per_map.setdefault(name, []).append((rep, boss, t, w))
    print('sonuçlar:', res)
    print('bitirilen harita indeksi dağılımı:', maps_reached[:4])
    print('ortalama tur:', sum(turns) / len(turns))
    for name, v in per_map.items():
        n = len(v)
        print(f"{name}: n={n} onarım={sum(x[0] for x in v)/n:.1f} tur, boss={sum(x[1] for x in v)/n:.1f} tur, "
              f"sıcaklık sonrası={sum(x[2] for x in v)/n:.2f}, refah={sum(x[3] for x in v)/n:.0f}")
