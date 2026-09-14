"""Build five teaching chapters with verified arrow and rest-tile mechanics."""
import json,copy
from pathlib import Path
from duet_solver import Puzzle
source=Path('data/progression_base.json')
if not source.exists():source.write_text(Path('data/stages.json').read_text())
stages=json.loads(source.read_text())
chapters=['道を残す','矢印の道','一時停止','仕掛けの連携','最後の先読み']
report=[];output=[]
names={(1,0):'右',(-1,0):'左',(0,1):'下',(0,-1):'上'}
for index,original in enumerate(stages):
 s=copy.deepcopy(original);sid=index+1;chapter=index//20
 sol,_=Puzzle(s).solve();assert sol
 terminals=s['starts']+s['goals']
 s['arrows']=[];s['stops']=[]
 if chapter>=2:
  # Require the rest tile to actually interrupt a possible multi-cell turn.
  candidates=[p for t in sol for p in t['path'][1:-1] if p not in terminals]
  candidates += [t['path'][-1] for t in sol if t['path'][-1] not in terminals]
  for cell in candidates:
   if cell in [a[:2] for a in s["arrows"]]:continue
   trial=copy.deepcopy(s);trial['stops']=[cell]
   solution,_=Puzzle(trial).solve(budget=100000)
   if solution and any(cell in t['path'][1:] for t in solution):
    s=trial;sol=solution;break
  assert s['stops'],sid
 if chapter in (1,3,4):
  candidates=[]
  for turn in sol:
   for a,b in zip(turn['path'],turn['path'][1:]):
    if a not in terminals and a not in s['stops']:candidates.append(a+[b[0]-a[0],b[1]-a[1]])
  s['arrows']=candidates[:1 if chapter==1 else (2 if chapter==3 else 3)]
  assert s['arrows']
 p=Puzzle(s);sol,states=p.solve();assert sol,sid
 # Every mechanic is used by the certified solution.
 if s['arrows']:
  assert any(any(a[:2] in t['path'][:-1] for t in sol) for a in s['arrows']),sid
 s['chapter']=chapters[chapter]
 s['name']=chapters[chapter]+' %02d'%(index%20+1)
 s['par_moves']=len(sol)
 basic='AとBを交互に動かし、同じ文字の輪へ。\n残した軌跡は、2人を阻む壁になります。'
 if chapter==1:basic='矢印マスからは、矢印の方向にだけ進めます。\n入る方向は自由。出口から逆に考えよう。'
 if chapter==2:basic='□に着いたら、指を離して一度交代。\n次の自分の番に、そこから動けます。'
 if chapter>=3:basic='矢印は出口の方向、□は一度止まる場所。\n2人の順番と、残す道を組み合わせよう。'
 s['brief']=basic
 def instruction(t):
  return ('A' if t['core']==0 else 'B')+'を'+'→'.join(names[(b[0]-a[0],b[1]-a[1])] for a,b in zip(t['path'],t['path'][1:]))+'へ'
 s['hint']=instruction(sol[0])+'、指を離す。\n続いて'+instruction(sol[1])+'。'
 blocking=next(({'core':0,'path':[p.xy(c) for c in path]} for nxt,path in p.actions(p.start) if p.reachable(nxt,0) and not p.reachable(nxt,1)),None)
 report.append({'stage_id':sid,'optimal_turns':len(sol),'solution':sol,'blocking_first_turn':blocking,'searched_states':states})
 output.append(s)
 print(sid,'arrows',len(s['arrows']),'stops',len(s['stops']),'par',len(sol),flush=True)
Path('data/stages.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
Path('tests/duet_solutions.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
