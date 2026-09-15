"""Generate a sequential cooperation campaign; retain certified solutions and difficulty evidence."""
import json,random,copy,time
from pathlib import Path
from bridge_solver import Puzzle
rng=random.Random(9152026)
root=Path(__file__).resolve().parents[1]
old=json.loads((root/'data/stages.json').read_text())
output=copy.deepcopy(old[:5]);report=[]
for s in output:
 sol,states=Puzzle(s).solve();report.append(dict(stage_id=s['stage_id'],solution=sol,optimal_turns=len(sol),blocking_first_turn=None,searched_states=states))
start=time.time();attempt=0
while len(output)<100:
 attempt+=1;sid=len(output)+1
 w,h=(5,5) if sid<41 else ((5,6) if sid<71 else (6,6))
 minimum=6 if sid<16 else (8 if sid<41 else (10 if sid<71 else 12))
 required=1 if sid<31 else (2 if sid<71 else 3)
 n=w*h;adj={c:[v for v in (c-1,c+1,c-w,c+w) if 0<=v<n and abs(c%w-v%w)+abs(c//w-v//w)==1] for c in range(n)}
 starts=rng.sample(range(n),2);pos=starts[:];paths=[[pos[0]],[pos[1]]];seen=[{pos[0]},{pos[1]}];bridges={};turns=[];failed=False
 for ti in range(minimum+rng.randint(0,3)):
  who=ti%2;path=[pos[who]]
  for _ in range(2):
   choices=[c for c in adj[path[-1]] if c not in seen[who] and c!=pos[1-who] and c not in starts]
   if not choices:break
   crossed=[c for c in choices if c in seen[1-who]]
   c=rng.choice(crossed if crossed and rng.random()<.6 else choices)
   if c in seen[1-who]:bridges[c]=1-who
   path.append(c);seen[who].add(c);paths[who].append(c)
   if rng.random()<.12:break
  if len(path)<2:failed=True;break
  pos[who]=path[-1];turns.append((who,path))
 if sid<=8 and len(bridges)!=1:continue
 if sid<=10 and len(bridges)>2:continue
 if failed or len(bridges)<required or any(pos[i] in seen[1-i] for i in (0,1)):continue
 xy=lambda c:[c%w,c//w]
 free=set(range(n))-(seen[0]|seen[1]);walls=[c for c in free if rng.random()<.83]
 s=dict(width=w,height=h,starts=list(map(xy,starts)),goals=list(map(xy,pos)),walls=list(map(xy,walls)),step_limit=2,bridges=[xy(c)+[owner] for c,owner in bridges.items()],keys=[],gates=[],arrows=[],stops=[])
 reserved=set(starts+pos)|set(bridges)
 channel_count=0 if sid<16 else (1 if sid<61 else 2)
 for channel in range(channel_count):
  choices=[]
  for it,(who,path) in enumerate(turns):
   for gate in path[1:]:
    if gate in reserved:continue
    for jt,(builder,kpath) in enumerate(turns[:it]):
     if builder==who:continue
     for key in kpath[1:]:
      if key not in reserved and key!=gate:choices.append((key,gate))
  if not choices:failed=True;break
  key,gate=rng.choice(choices);reserved.update((key,gate));s['keys'].append(xy(key)+[channel]);s['gates'].append(xy(gate)+[channel])
 if failed:continue
 if sid>=31:
  candidates=[(a,b) for who,path in turns for a,b in zip(path,path[1:]) if a not in reserved]
  rng.shuffle(candidates)
  for a,b in candidates[:1 if sid<71 else 2]:
   if a in reserved:continue
   s['arrows'].append(xy(a)+[b%w-a%w,b//w-a//w]);reserved.add(a)
  if not s['arrows']:continue
 if sid>=46:
  stops=[path[-1] for who,path in turns if path[-1] not in reserved]
  if not stops:continue
  s['stops']=[xy(rng.choice(stops))]
 p=Puzzle(s);sol,states=p.solve(budget=18000)
 if not sol or len(sol)<minimum:continue
 # The solution must cross the partner's bridges, not simply walk past decorations.
 visits=[set(tuple(c) for t in sol if t['core']==who for c in t['path']) for who in (0,1)]
 used=[b for b in s['bridges'] if tuple(b[:2]) in visits[0]&visits[1]]
 if len(used)<required:continue
 if any(not any(k[:2] in t['path'][1:] for t in sol) for k in s['keys']):continue
 if any(not any(g[:2] in t['path'][1:] for t in sol) for g in s['gates']):continue
 if any(not any(a[:2] in t['path'][:-1] for t in sol) for a in s['arrows']):continue
 if any(not any(cell in t['path'][1:] for t in sol) for cell in s['stops']):continue
 necessary=True
 for channel in range(channel_count):
  locked=copy.deepcopy(s);locked['keys']=[k for k in s['keys'] if k[2]!=channel]
  bypass,count=Puzzle(locked).solve(budget=18000)
  if bypass or count>18000:necessary=False;break
 if not necessary:continue
 # Reject levels solvable without cooperation, and record a demonstrably losing first move.
 no_bridge=copy.deepcopy(s);no_bridge['bridges']=[]
 bypass,bypass_states=Puzzle(no_bridge).solve(budget=18000)
 if bypass or bypass_states>18000:continue
 trap=None;choices=list(p.actions(p.start));viable=0
 for nxt,path in choices:
  continuation,count=p.solve(nxt,budget=18000)
  if continuation:viable+=1
  elif count<=18000 and trap is None:trap={'core':0,'path':[xy(c) for c in path]}
 if not trap and sid>=11:continue
 if sid>=31 and viable>len(choices)*.6:continue
 chapter='橋をつくる' if sid<16 else ('鍵を届ける' if sid<31 else ('橋と矢印' if sid<46 else ('交代の設計' if sid<61 else ('二つの鍵' if sid<76 else '連鎖する橋'))))
 s.update(stage_id=sid,name=chapter,chapter=chapter,par_moves=len(sol))
 s['brief']='色つきの点線は、その色の駒が先に通る場所。\n離れると相手用の橋に。渡って離れると崩れます。'
 if sid>=16:s['brief']='鍵を取って指を離すと、同じ番号の扉が開く。\n橋を作る順番と、鍵を取りに行く道を考えよう。'
 if sid>=31:s['brief']='橋・鍵・矢印を組み合わせて道をつなごう。\n先にゴールすると、相手を助けに戻れません。'
 if sid>=46:s['brief']='□では一度交代。橋は相手が渡ると崩れます。\n残す足場と、扉を開く順番が攻略の鍵。'
 if sid>=61:s['brief']='鍵1と鍵2は、それぞれ同じ番号の扉を開く。\n橋を渡る順番まで、2人分を先読みしよう。'
 d={(1,0):'右',(-1,0):'左',(0,1):'下',(0,-1):'上'}
 def hint(t):return ('A' if t['core']==0 else 'B')+'を'+'→'.join(d[(b[0]-a[0],b[1]-a[1])] for a,b in zip(t['path'],t['path'][1:]))+'へ'
 s['hint']=hint(sol[0])+'、指を離す。\n続いて'+hint(sol[1])+'。'
 output.append(s);report.append(dict(stage_id=sid,solution=sol,optimal_turns=len(sol),blocking_first_turn=None,losing_first_turn=trap,searched_states=states,bridge_crossings=len(used),legal_first_turns=len(choices),winning_first_turns=viable))
 print('stage',sid,'par',len(sol),'bridges',len(used),'choices',viable,'/',len(choices),'attempts',attempt,'secs',round(time.time()-start),flush=True)

(root/'data/stages.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
(root/'tests/duet_solutions.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
