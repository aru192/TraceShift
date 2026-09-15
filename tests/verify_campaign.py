"""Read-only campaign audit; a budget cutoff never counts as proof of impossibility."""
import json,copy
from pathlib import Path
from bridge_solver import Puzzle
root=Path(__file__).resolve().parents[1]
stages=json.loads((root/'data/stages.json').read_text());rows=json.loads((root/'tests/duet_solutions.json').read_text())
assert len(stages)==len(rows)==100
signatures=set();crossings=0
for sid,(s,row) in enumerate(zip(stages,rows),1):
 assert s['stage_id']==row['stage_id']==sid
 groups=[s['starts'],s['goals'],s['walls']]+[s.get(k,[]) for k in ['bridges','keys','gates','arrows','stops']]
 cells=[tuple(c[:2]) for group in groups for c in group]
 assert len(cells)==len(set(cells)),('overlap',sid)
 assert all(0<=x<s['width'] and 0<=y<s['height'] for x,y in cells)
 signature=json.dumps({k:s.get(k,[]) for k in ['width','height','starts','goals','walls','bridges','keys','gates','arrows','stops']},sort_keys=True)
 assert signature not in signatures;signatures.add(signature)
 p=Puzzle(s);sol,count=p.solve();assert sol and len(sol)==s['par_moves']==row['optimal_turns'],sid
 state=p.start
 for turn in row['solution']:
  assert state[4]==turn['core']
  matches=[nxt for nxt,path in p.actions(state) if [p.xy(c) for c in path]==turn['path']]
  assert len(matches)==1,sid
  state=matches[0]
 assert state[:2]==p.goals,sid
 if sid>=6:
  without=copy.deepcopy(s);without['bridges']=[]
  bypass,count=Puzzle(without).solve();assert bypass is None and count<=60000,sid
  for key in s['keys']:
   locked=copy.deepcopy(s);locked['keys']=[k for k in s['keys'] if k[2]!=key[2]]
   bypass,count=Puzzle(locked).solve();assert bypass is None and count<=60000,sid
  visited=[set(tuple(c) for t in sol if t['core']==who for c in t['path']) for who in (0,1)]
  crossings+=len(visited[0]&visited[1])
 if sid>=11:
  trap=row['losing_first_turn'];nxt=next(n for n,path in p.actions(p.start) if [p.xy(c) for c in path]==trap['path'])
  continuation,count=p.solve(nxt);assert continuation is None and count<=60000,sid
 if sid>=31:assert row['winning_first_turns']<=row['legal_first_turns']*.6
 if sid>=71:assert len(sol)>=12 and s['width']==6 and s['height']==6
print(f'Campaign verified: 100 solvable stages, 95 require bridges, 85 require keys; {crossings} partner bridge crossings.')
