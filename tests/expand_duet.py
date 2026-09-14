"""Deterministically add distinct, solver-verified dual-core puzzles."""
import json, random
from pathlib import Path
from duet_solver import Puzzle
random.seed(20260913)
file=Path('data/stages.json')
stages=json.loads(file.read_text())[:10]

def signature(s):
 forms=[]
 for flip in (False,True):
  for rot in range(4):
   def point(p):
    x,y=p;w,h=s['width'],s['height']
    if flip:x=w-1-x
    for _ in range(rot):x,y,w,h=h-1-y,x,h,w
    return x,y,w,h
   a=[point(p)[:2] for p in s['starts']];g=[point(p)[:2] for p in s['goals']]
   walls=sorted(point(p)[:2] for p in s['walls']);w,h=point([0,0])[2:]
   for swap in (False,True):
    forms.append(str((w,h,a[::-1] if swap else a,g[::-1] if swap else g,walls)))
 return min(forms)

seen={signature(s) for s in stages}
chapters=['道の分担','止まる勇気','出口の確保','遠回りの知恵','交代のリズム','二つの回廊','先読みの壁','細道の選択','ふたりの到達']
briefs=['自分の近道が、相手の道を塞ぐかも。\n2人分のルートを考えてから進みましょう。','最大まで進まず、途中で交代する手も。\n停止位置から次の一手を考えましょう。','ゴールから逆に道をたどってみよう。\n相手に必要なマスを残せていますか？']
def instruction(turn):
 names={(1,0):'右',(-1,0):'左',(0,1):'下',(0,-1):'上'}
 path=turn['path'];dirs=[names[(b[0]-a[0],b[1]-a[1])] for a,b in zip(path,path[1:])]
 return ('A' if turn['core']==0 else 'B')+'を'+'→'.join(dirs)+'へ'
tries=0
while len(stages)<100:
 tries+=1
 idx=len(stages)+1
 w,h=(5,5) if idx<=70 else (5,6)
 limit=2 if idx<=40 else 3
 cells=[[x,y] for y in range(h) for x in range(w)]
 terminals=random.sample(cells,4)
 walls=random.sample([p for p in cells if p not in terminals],random.randint(3,7 if h==5 else 10))
 s={'width':w,'height':h,'starts':terminals[:2],'goals':terminals[2:],'walls':walls,'step_limit':limit}
 sig=signature(s)
 if sig in seen:continue
 p=Puzzle(s);distances=[p.shortest(i) for i in (0,1)]
 if min(distances)<=limit or max(distances)>12:continue
 trap=next((path for nxt,path in p.actions(p.start) if p.reachable(nxt,0) and not p.reachable(nxt,1)),None)
 if not trap:continue
 solution,states=p.solve(budget=12000)
 if not solution or len(solution)<(5 if idx<=40 else 6) or len(solution)>11:continue
 lengths=[sum(len(t['path'])-1 for t in solution if t['core']==i) for i in (0,1)]
 if sum(lengths)-sum(distances)<2:continue
 seen.add(sig)
 chapter=(idx-11)//10
 s.update(stage_id=idx,name=chapters[chapter]+' %02d'%((idx-11)%10+1),par_moves=len(solution),brief=briefs[idx%3],hint=instruction(solution[0])+'、指を離して交代。\n続いて'+instruction(solution[1])+'。残りの道を考えよう。')
 stages.append(s)
 if idx%10==0:print('Verified:',idx,'attempts:',tries,flush=True)
stages[9]['brief']='これまでの判断を組み合わせるまとめの面。\n2人とも着けば成功。6手クリアにも挑戦。'
file.write_text(json.dumps(stages,ensure_ascii=False,indent=2)+'\n')
print('100 distinct layouts (including rotations/reflections/core swaps).',flush=True)
