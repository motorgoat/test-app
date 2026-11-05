const TOUCH=matchMedia('(hover:none)').matches;
/* ================= Kanten-Modell 0.2: Felder = Arbeit und Truppen, Kanten = Straßen ================= */
const ek=(a,b)=>a<b?a+'|'+b:b+'|'+a;
function dirTo(s,q){return same(s,q)?[q.p[0]-s.p[0],q.p[1]-s.p[1],q.p[2]-s.p[2]]:q.n.slice();}
function nbrDir(st,s,d,idx){const q=[s.p[0]+d[0],s.p[1]+d[1],s.p[2]+d[2]];if(q.every(x=>Math.abs(x)<=1))return idx.get(key(q,s.n));return idx.get(key(s.p,d));}
function isAct(st,idx,e){const A=st[e.a],B=st[e.b];return nbrDir(st,A,e.da,idx)===B&&nbrDir(st,B,e.db,idx)===A;}
function newEdge(s,q){const a=s.id<q.id?s:q,b=a===s?q:s;return{a:a.id,b:b.id,da:dirTo(a,b),db:dirTo(b,a),own:null,road:false};}
/* neue Nachbarschaften nach einer Drehung bekommen eine leere Kante; leere, gerissene Kanten passen sich an */
function syncEdges(){const idx=indexOf(S);S.forEach(s=>nbrs(s,idx).forEach(q=>{if(s.id>q.id)return;const k=ek(s.id,q.id);let e=E.get(k);
  if(!e){E.set(k,newEdge(s,q));return;}if(!isAct(S,idx,e)&&!e.road){const n=newEdge(s,q);e.da=n.da;e.db=n.db;}}));}
function mkCtx(st,Em){const idx=indexOf(st);const act=new Set();Em.forEach((e,k)=>{if(isAct(st,idx,e))act.add(k);});return{st,E:Em,idx,act};}
function fEdges(c,f){const out=[];nbrs(f,c.idx).forEach(q=>{const k=ek(f.id,q.id);if(c.act.has(k))out.push(k);});return out;}
/* Straßen sind Halbstücke: jedes Feld hat eigene, nach außen führende Straßen (s.rs: Richtung + Besitzer).
   Zwei Felder sind nur verbunden, wenn beide an der gemeinsamen Kante ein Stück haben. Die Stücke drehen mit ihrem Feld. */
const veq=(a,b)=>a[0]===b[0]&&a[1]===b[1]&&a[2]===b[2];
const stubTo=(f,q,o)=>(f.rs||[]).some(r=>veq(r.d,dirTo(f,q))&&(o==null||r.o===o));
const linked=(f,q,o)=>stubTo(f,q,o)&&stubTo(q,f,o);
/* Netz: vom Zentrum über vollständig verbundene eigene Straßen. reach = Netz plus die Felder, auf die eine eigene Straße aus dem Netz zeigt */
function netOf(c,o){const fields=new Set([o]),reach=new Set([o]),q=[o];
  while(q.length){const f=c.st[q.shift()];nbrs(f,c.idx).forEach(g=>{if(stubTo(f,g,o))reach.add(g.id);if(fields.has(g.id)||!linked(f,g,o))return;fields.add(g.id);reach.add(g.id);q.push(g.id);});}
  return{fields,reach};}
function allNets(c){const n={};OWN.forEach(o=>n[o]=netOf(c,o));return n;}
const strOf=o=>1+(S[o].v.werk?1:0);
const onSide=(c,o,f)=>same(c.st[f.id],c.st[o]);
/* Arbeiter: frei auf der eigenen Seite, sonst nur über Straßen. Krieger: nur über Straßen */
const reachW=(c,o,f,n)=>onSide(c,o,f)||n[o].reach.has(f.id);
const reachU=(c,o,f,n)=>n[o].reach.has(f.id);
const roadAt=(c,o,f,n)=>{const st=c.st[f.id];return nbrs(st,c.idx).some(q=>linked(st,q,o));};
/* Jedes Feld hat 4 Viertel (f.bs). Viertel 0 gehört dem Rohstoff (dort steht der Verarbeiter), der See ist ganz Wasser */
const bsOf=f=>f.bs||[null,null,null,null];
const cntB=(f,t)=>bsOf(f).filter(b=>b===t).length;
const QPOS=[[-.24,-.24],[.24,-.24],[-.24,.24],[.24,.24]];
let curQ=null;
function quarterAt(s,point){if(!point)return null;const l=s.group.worldToLocal(point.clone());return (l.x>0?1:0)+(l.z>0?2:0);}
const resOf=f=>YIELD[f.terr];
function yieldParts(c,f,o,n){const st=c.st[f.id];const w=Math.min(st.w||0,MAXW);return{w,road:roadAt(c,o,f,n)?1:0,prod:(st.w>0?2*bsOf(st).filter(b=>b&&PRODB[b]&&PRODB[b].terr===st.terr).length:0)+Math.max(0,cntB(st,'acker')-1)};}
/* Ertrag: Personen am Feld (+ Verarbeiter), eine verbundene Straße verdoppelt */
function yieldFor(c,f,o,n){const st=c.st[f.id];if(st.center||st.own!==o||!resOf(st))return 0;const P=yieldParts(c,f,o,n);return (P.w+P.prod)*(P.road?2:1);}
function fieldsOf(c,o){let k=0;c.st.forEach(f=>{if(!f.center&&f.own===o&&f.conq)k++;});return k;}
/* Besitz gehört dem Platz: Dreht sich ein Feld auf deine Seite, ist es deins, dein altes Feld gehört dem neuen Platz.
   Arbeiter und Krieger auf einem Feld, das den Besitzer wechselt, gehen nach Hause. Gebäude und Straßenstücke wechseln mit. */
let POS=new Map();
function initOwnership(){POS=new Map();S.forEach(f=>{if(f.center)return;const h=PL.find(pl=>same(pl,f));if(h&&OWN.includes(h.id)){f.own=h.id;f.conq=true;POS.set(key(f.p,f.n),h.id);}});}
function claimPos(f,o){POS.set(key(f.p,f.n),o);}
function settleOwners(st,ids){st.forEach(s=>{if(!ids.has(s.id)||s.center)return;const no=POS.get(key(s.p,s.n))||null;if(no===s.own&&(no||!s.own))return;
    const old=s.own;if(old!=null&&st===S&&S[old]){S[old].u+=(s.u||0);}s.u=0;s.own=no;s.conq=!!no;s.wall=false;(s.rs||[]).forEach(r=>r.o=no);
    if(st===S){syncFig(s);if(old!=null)syncFig(S[old]);}});}
function rotateWorld(st,Em,a,layer,d){const ids=new Set(st.filter(s=>s.p[a]===layer&&!s.center).map(s=>s.id));st.forEach(s=>{if(ids.has(s.id)&&s.rs)s.rs.forEach(r=>r.d=rv(r.d,a,d));});Em.forEach(e=>{if(ids.has(e.a))e.da=rv(e.da,a,d);if(ids.has(e.b))e.db=rv(e.db,a,d);});rotateSt(st,a,layer,d);settleOwners(st,ids);}
const cloneE=Em=>{const m=new Map();Em.forEach((e,k)=>m.set(k,Object.assign({},e,{da:e.da.slice(),db:e.db.slice()})));return m;};

/* ---------- Spielzustand ---------- */
const MAXW=3;
let E=new Map(),OWN=[],ME=null,AIS=[],nAI=3,tempo='runde',paused=false,tAcc=0,won=false,mode='work',aiRunning=false;
let ctx=null,nets=null;
function recalc(){syncEdges();ctx=mkCtx(S,E);nets=allNets(ctx);}
const meO=()=>ME.id;
function pay(o,c){for(const k in c)S[o].v.inv[k]-=c[k];}
function edgeAt(s,point){const loc=s.group.worldToLocal(point.clone());const ax=Math.abs(loc.x)>Math.abs(loc.z)?'x':'z';const sg=Math.sign(ax==='x'?loc.x:loc.z)||1;
  const v=new THREE.Vector3(ax==='x'?sg:0,0,ax==='z'?sg:0);const wq=new THREE.Quaternion();s.group.getWorldQuaternion(wq);v.applyQuaternion(wq);
  const d=[Math.round(v.x),Math.round(v.y),Math.round(v.z)];const q=nbrDir(S,s,d,ctx.idx);if(!q)return null;return{k:{f:s.id,q:q.id},ax,sg,s,q};}

/* Preise steigen mit jedem weiteren Stück derselben Art */
function priceOf(o,t){const scale=(c,add)=>{const r={};for(const k in c)r[k]=c[k]+add;return r;};
  if(t==='road')return {holz:3};
  if(t==='wall'){const n=S.filter(f=>f.own===o&&f.wall).length;return {stein:3+2*n};}
  const n=S.reduce((a,f)=>a+(f.own===o?cntB(f,t):0),0);const r={};for(const k in BCOST[t])r[k]=Math.ceil(BCOST[t][k]*(1+.6*n));if(t==='haus'&&n)r.stein=(r.stein||0)+n;return r;}
/* ---------- Straßen ---------- */
/* Straßen: durchgehend über eine Kante (beide Hälften). Pro Ausbaustufe eine Straße. Beim Drehen können die Hälften auseinanderreißen */
const roadsLeft=o=>S[o].v.stage-(S[o].v.roads||0);
function roadErr(o,k){const f=S[k.f],q=S[k.q];const mine=x=>x.own===o||x.id===o||same(x,S[o]);
  if(stubTo(f,q,o)&&stubTo(q,f,o))return 'Hier liegt schon deine Straße';
  if(!mine(f)&&!mine(q))return 'Eine Seite der Straße muss dir gehören';
  if(S[o].v.stage<2&&!same(f,q))return 'Über die Würfelkante geht es erst ab '+STAGE[2];
  if(roadsLeft(o)<=0)return 'Pro Ausbaustufe gibt es eine Straße. Die nächste kommt mit dem nächsten Ausbau';
  const pc=priceOf(o,'road');if(!afford(pc,S[o].v.inv))return 'Braucht '+costTxt(pc);return null;}
function buildRoad(o,k){const f=S[k.f],q=S[k.q];pay(o,priceOf(o,'road'));S[o].v.roads=(S[o].v.roads||0)+1;
  if(!stubTo(f,q,o))(f.rs=f.rs||[]).push({d:dirTo(f,q),o});if(!stubTo(q,f,o))(q.rs=q.rs||[]).push({d:dirTo(q,f),o});recalc();}

/* ---------- Felder: Arbeiter, Gebäude, Krieger ---------- */
function workErr(o,f){if(f.center)return f.id===o?'Am Startfeld wird nicht gearbeitet. Tipp Felder mit Rohstoff an':'Fremdes Startfeld';
  if(f.own&&f.own!==o)return 'Gehört '+S[f.own].v.name+'. Erobern geht mit Kriegern';
  if(!resOf(f))return 'Wiese: erst einen Acker anlegen, dann können hier Arbeiter Nahrung holen';
  if(!reachW(ctx,o,f,nets))return 'Nur auf deiner Seite oder über deine Straßen erreichbar';
  if(!(S[o].w>0))return 'Keine Bewohner frei. Klick aufs Zentrum kauft einen ('+buyPrice(o).gold+' Gold)';return null;}
function addWorker(o,f){S[o].w--;f.w=(f.w||0)+1;f.own=o;syncFig(S[o]);if(o===meO()&&!aiRunning)walkFig(S[o],f,()=>syncFig(f));else syncFig(f);}
function pullErr(o,f){if(f.own!==o||f.center)return 'Hier steht niemand von dir';if(!(f.w>0)&&!(f.u>0))return 'Hier steht niemand von dir';return null;}
function pull(o,f){if(f.w>0){f.w--;S[o].w++;}else{f.u--;S[o].u++;}if(!f.conq&&!f.w&&!f.u&&!bsOf(f).some(Boolean))f.own=null;syncFig(f);syncFig(S[o]);}
/* Viertel für ein Gebäude: Verarbeiter ins Rohstoff-Viertel, Haus und Acker in ein freies anderes (auf der Wiese alle 4) */
function slotFor(t,f,qi){const b=bsOf(f);if(qi!=null)return b[qi]?-1:qi;const k=[0,1,2,3].find(i=>!b[i]);return k==null?-1:k;}
function bErr(o,t,f,qi){if(f.center)return 'Das Zentrum baust du rechts mit „Ausbau“ aus';
  if(f.own&&f.own!==o)return 'Gehört '+S[f.own].v.name;if(f.own!==o&&!reachW(ctx,o,f,nets))return 'Nur auf deiner Seite oder über deine Straßen';
  if(f.terr==='wasser'&&t!=='fischer')return 'Auf dem See gehen nur Fischer';
  if(t==='acker'&&f.terr!=='wiese')return 'Acker nur auf Wiese';
  if(PRODB[t]&&PRODB[t].terr!==f.terr)return BNAME[t]+' braucht '+TERR[PRODB[t].terr].name;
  if(slotFor(t,f,qi)<0)return qi!=null?'In diesem Viertel steht schon '+BNAME[bsOf(f)[qi]]+'. Abreißen geht mit der Karte „Abreißen“':'Kein Viertel mehr frei';
  const pc=priceOf(o,t);if(!afford(pc,S[o].v.inv))return 'Braucht '+costTxt(pc);return null;}
function buildOn(o,t,f,qi){const k=slotFor(t,f,qi);if(k<0)return;pay(o,priceOf(o,t));f.bs=bsOf(f).slice();f.bs[k]=t;f.own=o;setFieldBuilding(f);}
/* Krieger: nur über Straßen. Auf eigene oder freie Felder 1 pro Tipp, auf gegnerische Felder greifen alle bereiten an */
function troopErr(o,f){if(!(S[o].u>0))return 'Keine Krieger bereit. Die Kaserne bringt jede Runde welche';if(f.center&&f.id!==o)return 'Startfelder kann man nicht erobern';
  if(f.id===o)return 'Krieger sind schon am Startfeld';if(!reachU(ctx,o,f,nets))return 'Krieger gehen nur über deine Straßen. Bau eine Straße an dieses Feld';return null;}
function sendTroop(o,f){if(f.own&&f.own!==o){return attack(o,f);}S[o].u--;f.u=(f.u||0)+1;f.own=o;f.conq=true;claimPos(f,o);(f.rs||[]).forEach(r=>r.o=o);syncFig(S[o]);syncFig(f);return null;}
function attack(o,f){const d=f.own;const A=S[o].u*strOf(o),D=(f.u||0)*strOf(d)+(f.w||0)*.5+(f.wall?3:0);
  if(A>D){const lose=Math.ceil(D/strOf(o));const left=S[o].u-lose;S[o].u=0;Object.assign(f,{own:o,conq:true,u:left,wall:false});claimPos(f,o);(f.rs||[]).forEach(r=>r.o=o);setFieldBuilding(f);syncFig(f);syncFig(S[o]);return 'win';}
  S[o].u=0;f.u=Math.max(0,(f.u||0)-Math.floor(A/strOf(d)));syncFig(S[o]);syncFig(f);return 'lose';}
/* Startfeld: Haus bringt Bewohner, Kaserne Krieger; Stufe begrenzt den Ausbau */
function homeErr(o,t){const v=S[o].v,l=v[t]||0;if(t==='markt'&&l>=3)return 'Höchste Stufe';if(l>=4)return 'Höchste Stufe';const mx=(t==='haus'||t==='markt')?v.stage:v.stage-1;if(l>=mx)return mx<1?'Erst ab '+STAGE[2]+': steig zuerst auf':'Erst aufsteigen (jetzt '+STAGE[v.stage]+')';const c=HCOST[t][l+1];if(!afford(c,v.inv))return 'Braucht '+costTxt(c);return null;}
function homeUp(o,t){const v=S[o].v;pay(o,HCOST[t][(v[t]||0)+1]);v[t]=(v[t]||0)+1;setHomeBuildings(S[o]);}
/* Platz: Startfeld 4, jede Hausstufe am Start +3, jedes Haus auf einem Feld +2. Bewohner und Krieger zählen */

const popOf=o=>S.reduce((a,f)=>a+((f.own===o||f.id===o)?(f.w||0):0),0);
const UPCD=12,GOLD_TICK=1;
const buyPrice=o=>({gold:4+Math.floor((S[o].v.bought||0)/3)});
function buyErr(o){const c=buyPrice(o);return afford(c,S[o].v.inv)?null:'Braucht '+costTxt(c);}
function buyPerson(o){pay(o,buyPrice(o));S[o].v.bought=(S[o].v.bought||0)+1;S[o].w++;syncFig(S[o]);}
function stageErr(o){const v=S[o].v,U=STAGEUP[v.stage+1];if(!U)return 'Höchste Stufe';const wait=UPCD-(round-(v.upAt||0));if(wait>0)return 'Der nächste Ausbau geht erst in '+wait+' Takt'+(wait>1?'en':'');if(!afford(U,v.inv))return 'Braucht '+costTxt(U);return null;}
function stageUp(o){const v=S[o].v;pay(o,STAGEUP[v.stage+1]);v.stage++;v.upAt=round;v.rot++;setChain(v);setMonument(S[o]);setHomeBuildings(S[o]);}
/* Ausbau des Zentrums: Zelt (+1) → Haus (+2, braucht Nahrung) → Marktplatz → Kaserne → Kaserne mit Werkstatt */
function setChain(v){v.haus=v.stage>=2?1:0;v.markt=v.stage>=3?1:0;v.kas=v.stage>=4?1:0;v.werk=v.stage>=5?1:0;}
const CHAINFX={2:'+1 Gold, Felder bis Stufe 2',3:'+1 Gold, Felder bis Stufe 3, 3:1 tauschen',4:'+1 Gold, Felder bis Stufe 4, 1 Krieger pro Takt (je 1 Nahrung)',5:'+1 Gold, stärkere Krieger, Mauern'};
const fieldHouses=o=>S.reduce((a,f)=>a+(f.own===o?cntB(f,'haus'):0),0);
const eatOf=o=>Math.floor(popOf(o)/5);
const goldOf=o=>GOLD_TICK*S[o].v.stage+S.reduce((a,f)=>a+(f.own===o&&!f.center?(f.lv||0):0),0);
const growthOf=goldOf;

/* Markt: Rohstoffe tauschen, Stufe 1 4:1, Stufe 2 3:1, Stufe 3 2:1 */
const rateOf=o=>S[o].v.markt?3:0;
function tradeErr(o,give,get){const r=rateOf(o);if(!r)return 'Erst einen Markt im Zentrum bauen';if(give===get)return 'Zwei verschiedene Rohstoffe wählen';if((S[o].v.inv[give]||0)<r)return 'Braucht '+r+' '+RES[give];return null;}
function trade(o,give,get){const r=rateOf(o),v=S[o].v;v.inv[give]-=r;v.inv[get]=(v.inv[get]||0)+1;}
/* ---------- Takt ---------- */
function tick(){if(won||phase!=='play'||busy||playingRots)return;round++;tAcc=0;const myGain={};
  S.forEach(f=>{if(f.center||f.own==null||!OWN.includes(f.own))return;const y=yieldFor(ctx,f,f.own,nets);if(!y)return;const r=resOf(f);S[f.own].v.inv[r]+=y;if(f.own===meO()){myGain[r]=1;floatAt(anchorOf(f,.25),'+'+y+RICON[r],'#2e5a2e');}});
  /* Bewohner: Zelt bringt 1 gratis, jeder weitere (Haus im Zentrum, Häuser auf Feldern) kostet 1 Nahrung. Kaserne: Krieger je 1 Nahrung */
  /* Gold kommt automatisch (Zentrum-Stufe + Häuser). Bewohner kauft man im Zentrum. Hunger: einer geht */
  OWN.forEach(o=>{const v=S[o].v;const g=goldOf(o);v.inv.gold=(v.inv.gold||0)+g;const k=Math.min(v.kas,v.inv.nahrung);v.inv.nahrung-=k;S[o].u+=k;
    const eat=eatOf(o);const hungry=v.inv.nahrung<eat;v.inv.nahrung=Math.max(0,v.inv.nahrung-eat);let left=false;
    if(hungry&&popOf(o)>2){if(S[o].w>0)S[o].w--;else{const f=S.filter(f=>f.own===o&&f.w>0).sort((a,b)=>b.w-a.w)[0];if(f){f.w--;syncFig(f);}}left=true;}
    syncFig(S[o]);if(o===meO())floatAt(anchorOf(S[o],.45),'+'+g+RICON.gold+(k?' +'+k+SWORD:''),'#8a6a00');
    if(o===meO()&&left)setTimeout(()=>hint('Hunger: '+popOf(o)+' Bewohner essen '+eat+' Nahrung pro Takt. Einer ist gegangen. Schick jemanden an den See oder auf einen Acker',3600),200);});
  const notes=[];AIS.forEach(pl=>{const t=aiAct(pl.id);if(t)notes.push(t);});aiLog=notes;
  recalc();checkEnd();refresh();readyCheck();gainPulse(Object.keys(myGain));if(rotQ.length)playRots();}
let wasReady=false;
function readyCheck(){const r=!stageErr(meO());if(r&&!wasReady&&STAGEUP[ME.v.stage+1])hint('Ausbau zu '+STAGE[ME.v.stage+1]+' ist jetzt möglich (rechts)',3500);wasReady=r;}
function checkEnd(){if(won)return;OWN.forEach(o=>{if(!won&&fieldsOf(ctx,o)>=WIN){won=true;showEnd(o===meO(),S[o]);}});}

/* ---------- KI ---------- */
let aiLog=[],aiRotQueued=false,warnRot=null;
function needW(o){const w=Object.assign({},W8),v=S[o].v,U=STAGEUP[v.stage+1];if(U)for(const r in U)if((v.inv[r]||0)<U[r])w[r]*=3;if(v.inv.holz<4)w.holz*=2;if(v.inv.nahrung<3*eatOf(o)+3)w.nahrung*=3;return w;}
function aiAct(o){aiRunning=true;const v=S[o].v,home=S[o],w=needW(o),did=[];
  try{
    if(!stageErr(o)){stageUp(o);did.push(STAGE[v.stage]);}
    for(let t=0;t<3&&!buyErr(o)&&v.inv.gold>=buyPrice(o).gold+Math.floor((STAGEUP[v.stage+1]?(STAGEUP[v.stage+1].gold||0):0)/2)&&v.inv.nahrung>eatOf(o)+1;t++){buyPerson(o);}
    if(fieldHouses(o)<v.stage-1&&v.inv.nahrung>4&&v.inv.holz>=priceOf(o,'haus').holz+2){const f=S.find(f=>!f.center&&!bErr(o,'haus',f)&&f.terr==='wiese')||S.find(f=>!f.center&&!bErr(o,'haus',f));if(f){buildOn(o,'haus',f);did.push('Haus');}}
    
    if(v.markt){const ks=RKEYS.filter(k=>k!=='werkzeug');for(let t=0;t<4;t++){const give=ks.reduce((a,k)=>(v.inv[k]||0)>(v.inv[a]||0)?k:a,ks[0]);const get=ks.filter(k=>w[k]>1||k==='nahrung').reduce((a,k)=>(v.inv[k]||0)<(v.inv[a]||0)?k:a,'nahrung');const get2=v.inv.nahrung<2*eatOf(o)+4?'nahrung':get;
      if((v.inv[give]||0)<12+rateOf(o)||tradeErr(o,give,get2))break;trade(o,give,get2);}}
    if(v.inv.nahrung<3&&v.stage>=2){const f=S.find(f=>!f.center&&f.terr==='wiese'&&!bErr(o,'acker',f));if(f){buildOn(o,'acker',f);did.push('Acker');}}
    /* Arbeiter auf die wertvollsten erreichbaren Felder */
    let n=0;for(let g=0;g<30&&home.w>0;g++){let best=null,bv=0;S.forEach(f=>{if(workErr(o,f)||(f.w||0)>=MAXW)return;const sc=(w[resOf(f)]||1)*(f.own===o?1:1.2)/(1+(f.w||0)*.5);if(sc>bv){bv=sc;best=f;}});if(!best)break;addWorker(o,best);n++;}
    if(n)did.push(n+' Arbeiter');
    /* Verarbeiter */
    for(const t of ['holzf','bruch','fischer']){const f=S.find(f=>!bErr(o,t,f)&&f.w>0);if(f){buildOn(o,t,f);did.push(BNAME[t]);break;}}
    /* Straßen: Stücke ergänzen, die eine Verbindung schließen, sonst zu neuen Feldern hinaus. Höchstens 1 pro Takt */
    const nStubs=S.reduce((a,f)=>a+(f.rs||[]).filter(r=>r.o===o).length,0);
    if((nStubs<2*S.filter(f=>f.own===o).length+6||v.inv.holz>priceOf(o,'road').holz+8)&&Math.random()<.7){let best=null,bv=.4;S.forEach(f=>{if(f.own&&f.own!==o)return;if(!(f.id===o||nets[o].fields.has(f.id)||f.own===o))return;
        nbrs(f,ctx.idx).forEach(q=>{const k={f:f.id,q:q.id};if(roadErr(o,k))return;let sc=stubTo(q,f,o)?3:0;
          if(!sc){if(q.center||(q.own===o&&q.conq&&nets[o].fields.has(q.id)))return;sc=(resOf(q)?(w[resOf(q)]||1)*.5:.2)+(q.own&&q.own!==o?1:0)+(q.own===o?.8:0);}
          sc+=Math.random()*.3;if(sc>bv){bv=sc;best=k;}});});
      if(best){buildRoad(o,best);did.push('Straße');}}
    /* Krieger: angreifen, wenn stark genug, sonst an der Grenze verteilen */
    if(home.u>0){let tgt=null;S.forEach(f=>{if(tgt||f.center||!f.own||f.own===o||troopErr(o,f))return;const D=(f.u||0)*strOf(f.own)+(f.w||0)*.5+(f.wall?3:0);if(home.u*strOf(o)>D+1)tgt=f;});
      if(tgt){const d=tgt.own;if(sendTroop(o,tgt)==='win'){did.push('erobert ein Feld von '+S[d].v.name);if(d===meO())setTimeout(()=>hint(v.name+' hat dir ein Feld abgenommen!',3500),400);}}
      else if(home.u>0){const free=S.filter(f=>!f.center&&!f.conq&&(!f.own||f.own===o)&&!troopErr(o,f));if(free.length){free.sort((a,b)=>(b.own===o?1:0)-(a.own===o?1:0)||(w[resOf(b)]||0)-(w[resOf(a)]||0));sendTroop(o,free[0]);did.push('Gebiet +1');}}
      if(!tgt&&home.u>0){const border=S.filter(f=>f.own===o&&!f.center&&reachU(ctx,o,f,nets)&&nbrs(f,ctx.idx).some(q=>q.own&&q.own!==o&&!q.center));if(border.length&&home.u>2)sendTroop(o,border[Math.floor(Math.random()*border.length)]);}}
    if(v.rot>0&&!rotQ.some(r=>r.o===o))queueAiRot(o);
  }finally{aiRunning=false;}
  return did.length?v.name+' (KI): '+did.join(', '):null;}
function scoreRot(o,a,layer,net){const st=cloneSt(S),Em=cloneE(E);for(let i=0;i<Math.abs(net);i++)rotateWorld(st,Em,a,layer,Math.sign(net));const c=mkCtx(st,Em),n=allNets(c);
  let s=0;st.forEach(f=>{if(f.center||f.own==null)return;if(f.own===o)s+=yieldFor(c,f,o,n);else if(f.own===meO())s-=.7*yieldFor(c,f,meO(),n);});return s;}
function queueAiRot(o){let best=null,bv=scoreRot(o,0,1,0)+1;for(let a=0;a<3;a++)for(const layer of[-1,1])for(const net of[1,2,-1]){const sc=scoreRot(o,a,layer,net);if(sc>bv){bv=sc;best={c:{a,layer},net};}}
  if(!best)return;S[o].v.rot--;rotQ.push({o,c:best.c,net:best.net});}
/* Vorgemerkte Drehungen: alle am Rundenende, nacheinander */
let rotQ=[],playingRots=false;
function markRots(){S.forEach(q=>{if(q.hl&&!pendingRot)q.hl.visible=false;});}
function playRots(){if(!rotQ.length)return;playingRots=true;busy=true;const q=rotQ.slice();rotQ=[];
  hint('Drehungen: '+q.map(r=>r.o===meO()?'du drehst':S[r.o].v.name+' dreht').join(', '),2200+q.length*1300);
  const next=()=>{const r=q.shift();if(!r){busy=false;playingRots=false;refresh();return;}
    S.forEach(s=>{if(!s.hl)return;const m=s.p[r.c.a]===r.c.layer;s.hl.visible=m;if(m)s.hl.material.color.copy(col(r.o===meO()?'#ffffff':S[r.o].v.c));});
    setTimeout(()=>{const pv=new THREE.Group();root.add(pv);cubies.filter(c=>c.pos[r.c.a]===r.c.layer).forEach(c=>pv.attach(c.group));
      tween(650+220*Math.abs(r.net),k=>pv.quaternion.setFromAxisAngle(AX[r.c.a],r.net*Math.PI/2*easeIO(k)),()=>{finishPivot(pv);S.forEach(s=>{if(s.hl)s.hl.visible=false;});applyRot(r.c,r.net);busy=true;setTimeout(next,250);});},450);};
  next();}
/* Eigene Drehung: Vorschau zurückdrehen und fürs Rundenende vormerken */
function confirmRot(){const r=pendingRot;if(!r)return;pendingRot=null;ME.v.rot--;rotQ.push({o:meO(),c:r.c,net:r.net});phase='play';busy=true;
  tween(260,k=>r.pivot.quaternion.setFromAxisAngle(AX[r.c.a],r.net*Math.PI/2*(1-easeIO(k))),()=>{finishPivot(r.pivot);busy=false;markRots();hint('Drehung vorgemerkt: Sie passiert am Ende des Takts, zusammen mit den Drehungen der KI',3200);refresh();});}
function applyRot(c,net){const d=Math.sign(net);for(let i=0;i<Math.abs(net);i++){cubies.forEach(q=>{if(q.pos[c.a]===c.layer)q.pos=rv(q.pos,c.a,d);});rotateWorld(S,E,c.a,c.layer,d);}
  flash={ids:new Set(S.filter(q=>q.p[c.a]===c.layer).map(q=>q.id)),until:performance.now()+1800};recalc();checkEnd();refresh();}

/* ---------- Darstellung ---------- */
/* Rohstoff auf einem Viertel des Feldes, der Rest Bauplatz */
const QX=-.22,QZ=-.22;
function makeTile2(s){const g=s.group;if(s.center){makePlaza(s);s.home=new THREE.Group();s.home.position.y=.1;g.add(s.home);s.army=new THREE.Group();s.army.position.y=.1;g.add(s.army);return;}
  const fm=new THREE.MeshStandardMaterial({color:col('#c9c2b2'),roughness:.8});s.frameMat=fm;
  s.frames=[];[[0,.457,.95,.032],[0,-.457,.95,.032],[.457,0,.032,.882],[-.457,0,.032,.882]].forEach(([x,z,w,d])=>{const f=mesh(box(w,.024,d),fm,x,.103,z);f.castShadow=false;f.visible=false;g.add(f);s.frames.push(f);});
  const GROUND={wiese:'#86b45f',wald:'#5f9a4e',wasser:'#86b45f',berg:'#a9a897',gold:'#d8c27c',eisen:'#9a6f5c',lehm:'#c99a6a'};const base=new THREE.Color(GROUND[s.terr]||TERR.wiese.c);base.offsetHSL(R(-.012,.012),R(-.05,.05),R(-.035,.035));g.add(mesh(box(.95,.1,.95),new THREE.MeshStandardMaterial({color:base.convertSRGBToLinear(),roughness:.95}),0,.05,0));
  for(let i=0;i<3;i++){const f=mesh(sph(.018,6),M(['#f4f0e4','#f2c94c','#d97a8a'][i%3]),R(.05,.35),.11,R(.05,.35));f.castShadow=false;g.add(f);}
  const t=s.terr;
  if(t==='wasser'){const wv=mesh(box(.95,.03,.95),new THREE.MeshStandardMaterial({color:col('#4d9bd3'),roughness:.18,metalness:.05}),0,.124,0);wv.castShadow=false;g.add(wv);}
  if(t==='wald'){[[-.32,-.32],[-.12,-.3],[-.3,-.12],[-.14,-.14]].forEach(([x,z])=>{const tr=makeTree(R(.75,.95),Math.random()<.5);tr.position.set(x,.1,z);g.add(tr);});}
  if(t==='berg'){const m=new THREE.Group();m.position.set(QX,.1,QZ);m.scale.setScalar(.66);
    const r1=mesh(dodeca(.27),M('#8e877a',{flatShading:true,roughness:1}),0,.12,0);r1.scale.set(1.05,1.15,1.05);m.add(r1);const sn=mesh(dodeca(.12),M('#f5f3ee',{flatShading:true}),0,.37,0);sn.scale.set(1.1,.7,1.1);m.add(sn);
    [[.3,.04,.18,.09],[.2,.03,-.25,.07]].forEach(([x,y,z,r])=>m.add(mesh(dodeca(r),M('#a39d90',{flatShading:true}),x,y,z)));g.add(m);}
  if(t==='gold'){const m=new THREE.Group();m.position.set(QX,.1,QZ);m.scale.setScalar(.7);m.add(mesh(cyl(.2,.26,.08,7),M('#7a5f2e',{flatShading:true}),0,.04,0));
    const gm=M('#ffcf33',{metalness:.75,roughness:.22,emissive:col('#a87800'),emissiveIntensity:.45,flatShading:true});[[0,.16,0,.11],[.12,.11,.06,.08],[-.11,.11,.05,.08],[.03,.1,-.12,.08],[-.05,.24,-.02,.07]].forEach(([x,y,z,r])=>m.add(mesh(dodeca(r),gm,x,y,z)));g.add(m);}
  if(t==='eisen'){const m=new THREE.Group();m.position.set(QX,.1,QZ);m.scale.setScalar(.66);const r1=mesh(dodeca(.25),M('#4c4f57',{flatShading:true,roughness:.9}),0,.11,0);r1.scale.set(1.1,.95,1.1);m.add(r1);
    const om=M('#d0612a',{flatShading:true,roughness:.5,metalness:.3});[[.15,.2,.12],[-.17,.16,.1],[.05,.28,-.12],[.2,.07,-.12]].forEach(([x,y,z])=>m.add(mesh(dodeca(.07),om,x,y,z)));
    const ing=M('#8b9099',{metalness:.6,roughness:.35});[[.3,.03],[.36,.08]].forEach(([x,z],k)=>m.add(mesh(box(.12,.05,.06),ing,x,.025+k*.05,z+.15)));g.add(m);}
  if(t==='lehm'){g.add(mesh(box(.38,.02,.34),M('#8a5034',{roughness:1}),QX,.105,QZ));[[.0,.0],[-.08,.06]].forEach(([x,z],i)=>g.add(mesh(box(.1,.045,.06),M(i?'#b86c45':'#c4794f'),QX+.15+x,.125+i*.045,QZ+.12+z)));}
  s.folk=new THREE.Group();s.folk.position.y=.1;g.add(s.folk);s.army=new THREE.Group();s.army.position.y=.1;g.add(s.army);
  addHL(s);}
function setFieldBuilding(f){if(f.bObj)f.group.remove(f.bObj);f.bObj=null;const g=new THREE.Group();
  bsOf(f).forEach((t,i)=>{if(!t)return;const b=makeBuilding(t,1);const [x,z]=QPOS[i];const pr=false;
    if(t==='acker'){b.scale.set(.42,1,.42);b.position.set(x,.1,z);}else{b.scale.setScalar(pr?.6:.75);b.position.set(pr?x+.13:x,.1,pr?z+.13:z);}g.add(b);});
  if(f.wall){[[0,.45],[0,-.45],[.45,0],[-.45,0]].forEach(([x,z])=>{const w=mesh(box(x?.04:.86,.08,x?.86:.04),M('#9b9384',{flatShading:true}),x,.15,z);g.add(w);});}f.group.add(g);f.bObj=g;}
function setHomeBuildings(h){if(!h.home)return;while(h.home.children.length)h.home.remove(h.home.children[0]);const v=h.v;
  if(v.haus>0){const hb=makeHouse(v.haus);hb.scale.setScalar(.7);hb.position.set(-.28,0,.28);h.home.add(hb);}
  if(v.werk>0){const w=makeBuilding('werk',1);w.scale.setScalar(.5);w.position.set(-.28,0,-.28);h.home.add(w);}
  if(v.markt>0){const m=new THREE.Group();m.position.set(.3,0,-.3);const aw=['#c7443a','#f4f0e4'];for(let i=0;i<v.markt+1;i++){const st=new THREE.Group();st.position.set((i-v.markt/2)*.1,0,0);
      [[-.035,-.03],[.035,-.03],[-.035,.03],[.035,.03]].forEach(([x,z])=>st.add(mesh(cyl(.005,.005,.09,4),M('#7a5a3e'),x,.045,z)));st.add(mesh(box(.08,.025,.07),M('#b88a5a'),0,.035,0));st.add(mesh(box(.095,.012,.085),M(aw[i%2]),0,.095,0));m.add(st);}h.home.add(m);}
  if(v.kas>0){const k=new THREE.Group();k.position.set(.28,0,.28);k.add(mesh(box(.2,.14+.04*v.kas,.16),M('#8f8471'),0,.07+.02*v.kas,0));k.add(mesh(cyl(.006,.006,.3,5),M('#5b4636'),.08,.2,0));k.add(mesh(box(.1,.06,.005),M('#c7443a'),.13,.32,0));h.home.add(k);}}
/* Figuren nur bei eigenen Feldern zeigen: der Gegner sieht nicht, wie viele dort stehen */
function syncFig(f){const mine=f.own===meO()||f.id===meO();const w=f.w;f.w=mine?(f.w||0):0;syncFolk(f);f.w=w;
  if(!f.army)return;while(f.army.children.length)f.army.remove(f.army.children[0]);if(!mine)return;
  for(let i=0;i<Math.min(5,f.u||0);i++){const p=new THREE.Group();p.add(mesh(cyl(.02,.026,.07,6),M('#8e2b22'),0,.035,0));p.add(mesh(sph(.017,8),M('#e3c4a0'),0,.085,0));p.add(mesh(box(.006,.12,.006),M('#4a4f5c'),.03,.07,0));p.scale.setScalar(1.6);const a=i/5*Math.PI*2+.3;p.position.set(f.center?Math.cos(a)*.15+.1:Math.cos(a)*.12+.2,0,f.center?Math.sin(a)*.15-.1:Math.sin(a)*.12-.2);f.army.add(p);}}
function syncAll(){S.forEach(syncFig);}
function edgeMid(e,lift){const A=new THREE.Vector3(),B=new THREE.Vector3();S[e.a].group.getWorldPosition(A);S[e.b].group.getWorldPosition(B);const m=A.add(B).multiplyScalar(.5);
  const n=new THREE.Vector3(...S[e.a].n).add(new THREE.Vector3(...S[e.b].n)).normalize();return m.addScaledVector(n,lift||.12);}
const edgeChips=[];
function layoutEdges(){const wq=new THREE.Quaternion();
  S.forEach(s=>{if(s.eg)s.group.remove(s.eg);s.eg=new THREE.Group();s.eg.position.y=s.terr==='wasser'?.13:.106;s.group.add(s.eg);s.group.getWorldQuaternion(wq);s._inv=wq.clone().invert();});
  const RM=M('#cdbb95',{roughness:1}),RL=M('#e4d8bb',{roughness:1});
  S.forEach(s=>{const rs=s.rs||[];if(!rs.length)return;if(rs.length>1||s.center)s.eg.add(mesh(box(.16,.02,.16),RM,0,.01,0));
    rs.forEach(r=>{const loc=new THREE.Vector3(...r.d).applyQuaternion(s._inv);const arm=new THREE.Group();arm.rotation.y=Math.atan2(loc.x,loc.z);s.eg.add(arm);
      const q=nbrDir(S,s,r.d,ctx.idx);const ok=q&&stubTo(q,s);arm.add(mesh(box(.16,.02,.475),ok?RM:RL,0,.01,.2375));});});}
/* Rahmen: erobert = volle Farbe, nur mit Arbeitern besetzt = blass */
function tintFields(){S.forEach(s=>{const o=s.center?(OWN.includes(s.id)?s.id:null):s.own;const full=s.center||s.conq;if(s.frames)s.frames.forEach(m=>m.visible=o!=null);s._tint=col(o==null?'#c9c2b2':'#'+new THREE.Color(S[o].v.c).lerp(new THREE.Color('#c9c2b2'),full?.15:.72).getHexString());});}
function addChip(s,html,cls,lift){const el=document.createElement('div');el.className='iIT_chip'+(cls?' '+cls:'');el.innerHTML=html;labels.appendChild(el);chips.push({el,s,lift});}
function updateMarks(){chips.forEach(c=>c.el.remove());chips=[];edgeChips.forEach(c=>c.el.remove());edgeChips.length=0;
  S.forEach(s=>{if(!s.hl)return;if(warnRot&&s.hl.visible)return;s.hl.visible=false;});}
function renderBar(){renderNav();const v=ME.v,bar=$('#iIT_bar');
  bar.innerHTML='<table class="iIT_inv"><tr><th class="iIT_tl">'+'Takt '+round+'</th>'+RKEYS.map(k=>'<th title="'+RES[k]+'">'+RICON[k]+'</th>').join('')+'<th title="Freie Bewohner">'+PICON+'</th><th title="Krieger bereit">'+SWORD+'</th><th title="Gold pro Takt">Gold/T</th></tr>'+
    '<tr class="iIT_cur"><td class="iIT_tl">'+vdot(v)+'<b>'+v.name+'</b><span>'+STAGE[v.stage]+' · '+fieldsOf(ctx,meO())+'/'+WIN+'</span></td>'+RKEYS.map(k=>'<td id="iIT_r_'+k+'">'+v.inv[k]+'</td>').join('')+'<td>'+ME.w+'</td><td>'+ME.u+'</td><td title="Bewohner essen '+eatOf(meO())+' Nahrung pro Takt">+'+goldOf(meO())+'</td></tr></table>';
  const U=STAGEUP[v.stage+1];
  $('#iIT_land').innerHTML='<b>'+vdot(v)+'Gelb (du) · '+STAGE[v.stage]+'</b><small>Gebiet '+fieldsOf(ctx,meO())+'/'+WIN+' Felder · Drehungen: '+v.rot+(U?' · nächste Stufe: '+costTxt(U):'')+'</small>';}
function renderNav(){const n=$('#iIT_nav');n.innerHTML=PL.map(pl=>'<button style="background:'+pl.v.c+'" data-pl="'+pl.id+'" title="'+pl.v.name+'" aria-label="Zu '+pl.v.name+' drehen"></button>').join('');
  n.querySelectorAll('button').forEach(b=>b.addEventListener('click',()=>focusOn(S[+b.dataset.pl])));}
function renderVils(){const box=$('#iIT_vils');const lg=$('#iIT_ailog');if(lg)lg.textContent=aiLog.length?'Letzte KI-Züge: '+aiLog.join(' · '):'';
  box.innerHTML=PL.map(pl=>{const v=pl.v,own=OWN.includes(pl.id);return '<button class="iIT_vil'+(pl===ME?' iIT_on':'')+(own?'':' iIT_empty')+'" id="iIT_v_'+pl.id+'">'+vdot(v)+'<b>'+v.name+(pl===ME?' (du)':own?' (KI)':' (frei)')+'</b><em>'+(own?fieldsOf(ctx,pl.id):'')+'</em><small>'+(own?STAGE[v.stage]+' · '+fieldsOf(ctx,pl.id)+' Felder':'niemand')+'</small></button>';}).join('');
  PL.forEach(pl=>$('#iIT_v_'+pl.id).addEventListener('click',()=>focusOn(pl)));}
const MINUS='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" stroke="#c7443a" stroke-width="3" stroke-linecap="round"/></svg>';
const MODES=[['work','Ausbauen',STARICON,null],['road','Straße',BICON.strasse,()=>priceOf(meO(),'road')],['wall','Mauer',WALLICON,()=>priceOf(meO(),'wall')],['troop','Krieger',SWORD,null]];
const MODETXT={_old:TOUCH?'Feld antippen: Bewohner hin · lange drücken: zurück':'Linksklick ins Feld: Bewohner hin · Rechtsklick: zurück',pull:'Feld antippen: 1 Arbeiter (oder Krieger) kommt zurück. Auch: lange aufs Feld drücken',road:'Feld nahe der Kante antippen: Die Straße führt über diese Kante und verdoppelt den Ertrag beider Felder. Pro Ausbaustufe eine',
  haus:'Ins Viertel eines eigenen Felds klicken: Haus, +1 Gold pro Takt',acker:'Wiese antippen: Acker für Nahrung',holzf:'Eigenen Wald antippen: +2 mit Arbeitern',fischer:'Eigenen See antippen: +2 mit Arbeitern',bruch:'Eigenen Berg antippen: +2 mit Arbeitern',
  wall:'Eigenes Feld antippen: Mauer, +3 Verteidigung (braucht Werkstatt)',work:'Feld antippen: zeigt, was dort geht. Nochmal tippen oder Knopf = ausführen',demo:'Ins Viertel klicken: das Gebäude dort wird abgerissen (ohne Erstattung)',troop:'Feld über deine Straßen antippen. Auf Gegnerfelder greifen alle bereiten Krieger an'};
let tradeGive='stein',tradeGet='nahrung';
function renderDock(extra){const tx=$('#iIT_phaseText'),cards=$('#iIT_cards'),acts=$('#iIT_acts');cards.innerHTML='';acts.innerHTML='';const v=ME.v,o=meO();
  $('#iIT_pips').innerHTML='';$('#iIT_phase').classList.toggle('iIT_roll',phase==='rotate');
  const tb=$('#iIT_tempo');const mine=rotQ.filter(r=>r.o===meO()).length;tb.innerHTML=(mine?'<button class="iIT_act iIT_panel" id="iIT_unrot">Drehung zurücknehmen</button>':'')+'<button class="iIT_act iIT_panel" id="iIT_pause">'+(paused?'▶ Weiter':'❚❚ Pause')+'</button><span class="iIT_bar2" title="Bis zum nächsten Takt"><i id="iIT_prog"></i></span><button class="iIT_act iIT_panel" id="iIT_next" title="Takt sofort beenden">⏭</button>';
  $('#iIT_next').addEventListener('click',()=>tick());$('#iIT_pause').addEventListener('click',()=>{paused=!paused;refresh();});
  if($('#iIT_unrot'))$('#iIT_unrot').addEventListener('click',()=>{const k=rotQ.findIndex(r=>r.o===meO());if(k>=0){rotQ.splice(k,1);ME.v.rot++;markRots();refresh();}});
  if(phase==='rotate'){tx.textContent=pendingRot?pendingRot.text:'Drehung vormerken: tipp auf einen Pfeil (mehrmals = weiter). Die Zeit steht, bis du fertig bist';
    if(pendingRot){const ok=document.createElement('button');ok.className='iIT_btn';ok.id='iIT_rotOk';ok.textContent='Vormerken';ok.addEventListener('click',confirmRot);const no=document.createElement('button');no.className='iIT_act iIT_panel';no.textContent='Zurück';no.addEventListener('click',cancelRot);acts.appendChild(no);acts.appendChild(ok);}
    const ab=document.createElement('button');ab.className='iIT_act iIT_panel';ab.textContent='Doch nicht drehen';ab.addEventListener('click',()=>{if(pendingRot)cancelRot();phase='play';refresh();});acts.appendChild(ab);return;}
  if(hintMsg&&performance.now()<hintUntil)tx.textContent=hintMsg;else tx.textContent=extra||(mode==='work'?(TOUCH?'Tipp':'Klick')+' ein Feld an: ↑ = ausbauen möglich, + = kaufen möglich':MODETXT[mode]);
  MODES.forEach(([m,name,ico,cf])=>{if(m==='wall'&&!v.werk)return;const b=document.createElement('button');b.className='iIT_card iIT_panel'+(mode===m?' iIT_sel':'')+(m==='pull'?' iIT_touchOnly':'');b.id='iIT_m_'+m;
    const c=cf&&cf();b.innerHTML=ico+'<strong>'+name+(m==='road'?' ('+Math.max(0,roadsLeft(meO()))+')':'')+'</strong><span class="iIT_price">'+(m==='work'?ME.w+' frei':m==='troop'?ME.u+' bereit':c?costHtml(c,v.inv):'')+'</span>';
    b.addEventListener('click',()=>{mode=mode===m?'work':m;clearHover();refresh();});cards.appendChild(b);});
  const cur=document.createElement('div');cur.className='iIT_chainNow iIT_panel';cur.id='iIT_chainNow';cur.innerHTML='<b>Zentrum: '+STAGE[v.stage]+'</b><small>+'+goldOf(o)+' Gold pro Takt · Bewohner: aufs Zentrum klicken ('+buyPrice(o).gold+' Gold)'+(v.kas?' · '+v.kas+' Krieger pro Takt':'')+'</small>';acts.appendChild(cur);
  if(v.markt){const ks=RKEYS.filter(k=>k!=='werkzeug');const opt=sel=>ks.map(k=>'<option value="'+k+'"'+(k===sel?' selected':'')+'>'+RES[k]+'</option>').join('');const tw=document.createElement('span');tw.className='iIT_trade iIT_panel';tw.id='iIT_trade';
    const te=tradeErr(o,tradeGive,tradeGet);tw.innerHTML='<select id="iIT_tGive" aria-label="Gib">'+opt(tradeGive)+'</select><b>'+rateOf(o)+' → 1</b><select id="iIT_tGet" aria-label="Bekomme">'+opt(tradeGet)+'</select><button class="iIT_act" id="iIT_tGo"'+(te?' disabled title="'+te+'"':'')+'>Tauschen</button>';acts.appendChild(tw);
    tw.querySelector('#iIT_tGive').addEventListener('change',e=>{tradeGive=e.target.value;refresh();});tw.querySelector('#iIT_tGet').addEventListener('change',e=>{tradeGet=e.target.value;refresh();});
    tw.querySelector('#iIT_tGo').addEventListener('click',()=>{if(!tradeErr(o,tradeGive,tradeGet)){trade(o,tradeGive,tradeGet);refresh();}});}
  const SU=STAGEUP[v.stage+1];if(SU&&!stageErr(o)){const sb=document.createElement('button');sb.className='iIT_act iIT_panel iIT_ready';sb.id='iIT_stageup';const se=stageErr(o);
    sb.innerHTML=STARICON+'Ausbau: '+STAGE[v.stage+1]+' <small>'+costHtml(SU,v.inv)+'<span class="iIT_fx"> → '+CHAINFX[v.stage+1]+', +1 Drehung</span></small>';sb.disabled=!!se;sb.title=se||'';sb.addEventListener('click',()=>{if(!stageErr(o)){stageUp(o);hint(STAGE[v.stage]+' gebaut. Du hast eine Drehung verdient',3500);refresh();}});acts.appendChild(sb);}
  if(v.rot>0){const rb=document.createElement('button');rb.className='iIT_btn';rb.id='iIT_rot';rb.textContent='Drehung vormerken ('+v.rot+')';rb.addEventListener('click',startRotate);acts.appendChild(rb);}}
function startRotate(){if(ME.v.rot>0&&!busy){closeMenu();phase='rotate';clearHover();refresh();}}
function refresh(){if(!ctx)recalc();layoutEdges();tintFields();renderBar();renderVils();renderDock();updateMarks();if(typeof renderSel==='function')renderSel();S.forEach(q=>{if(q.hl&&sel===q.id&&phase==='play'&&mode==='work'){q.hl.visible=true;q.hl.material.color.copy(col('#ffffff'));}});}

/* ---------- Info und Hover ---------- */
function fieldInfo(s){const o=meO();
  if(s.center)return [s.v.name+(OWN.includes(s.id)?(s.id===o?' · dein Zentrum':' · Zentrum der KI'):' · frei'),s.id===o?'Ausbau: '+STAGE[s.v.stage]+' · '+s.w+' Bewohner, '+s.u+' Krieger bereit':'Startfelder drehen nie mit und sind nicht eroberbar'];
  const r=resOf(s);const bl=bsOf(s).filter(Boolean);let head=TERR[s.terr].name+(bl.length?' ('+bl.map(b=>BNAME[b]).join(', ')+')':'')+(s.own!=null?(s.conq?' · Gebiet von ':' · besetzt von ')+S[s.own].v.name+(s.own===o?' (dir)':''):' · frei');
  if(s.own===o&&r){const P=yieldParts(ctx,s,o,nets);return[head,(s.w||0)+' Arbeiter'+(s.w>MAXW?' (zählen nur '+MAXW+')':'')+(P.road?' · ×2 Straße':'')+(P.prod?' · +'+P.prod+' Gebäude':'')+' · liefert '+yieldFor(ctx,s,o,nets)+' '+RES[r]+' pro Takt'+(s.u?' · '+s.u+' Krieger':'')+(s.conq?'':' · noch nicht erobert: Krieger hinschicken')];}
  if(s.own&&s.own!==o)return[head,'Wie viele Arbeiter und Krieger dort sind, siehst du nicht'];
  return[head,(r?'Arbeiter können hier arbeiten. ':'')+'Erobern: Straße hinbauen, Krieger hinschicken'];}
function showFieldInfo(s){clearHover();const [a,b]=fieldInfo(s);tag(s,a+'<small>'+b+'</small>');}
/* Feldrand (äußeres Stück) = Kante für Straßen */
function edgeZone(s,point){if(s.center)return null;const loc=s.group.worldToLocal(point.clone());const m=Math.max(Math.abs(loc.x),Math.abs(loc.z));return m>.34?edgeAt(s,point):null;}
function hoverEdge(h){if(edgeMark.parent)edgeMark.parent.remove(edgeMark);canvas.style.cursor='';if(!h||phase!=='play'){if(!hintMsg)renderDock();return;}const s=S[h.sid];const o=meO();
  if(mode==='road'){const r=edgeAt(s,h.point);if(!r)return;const err=roadErr(o,r.k);edgeMark.position.set(r.ax==='x'?r.sg*.42:0,.14,r.ax==='z'?r.sg*.42:0);edgeMark.rotation.y=r.ax==='x'?Math.PI/2:0;edgeMark.scale.set(.85,1,.6);
    edgeMark.material.color.copy(col(err?'#ff7a6a':'#ffffff'));s.group.add(edgeMark);canvas.style.cursor=err?'not-allowed':'pointer';status(err||'Straße hier: '+costTxt(priceOf(o,'road')),!!err);return;}
  curQ=quarterAt(s,h.point);const err=actErr(s);canvas.style.cursor=err?'not-allowed':'pointer';const [a,b]=fieldInfo(s);status(err?err:a+' · '+b,!!err);}
function actErr(s){const o=meO();if(mode==='demo'){if(s.own!==o||s.center)return 'Nur auf deinen Feldern';const qi=curQ;if(qi==null||!bsOf(s)[qi])return 'In diesem Viertel steht nichts';return null;}if(mode==='work')return workErr(o,s);if(mode==='pull')return pullErr(o,s);if(mode==='troop')return troopErr(o,s);
  if(mode==='wall'){if(s.own!==o||s.center)return 'Nur auf deinen Feldern';if(s.wall)return 'Hier steht schon eine Mauer';const pc=priceOf(o,'wall');return afford(pc,ME.v.inv)?null:'Braucht '+costTxt(pc);}
  return bErr(o,mode,s,curQ);}
function status(t,bad){if(hintMsg)return;const el=$('#iIT_phaseText');if(el)el.textContent=t;$('#iIT_phase').classList.toggle('iIT_msg',!!bad);}

/* ---------- Feldmenü: alles passiert über einen Tipp ins Feld ---------- */
let menuFor=null,menuEdge=null,menuXY=null;
function closeMenu(){const m=$('#iIT_menu');if(m)m.hidden=true;menuFor=null;menuEdge=null;}
function menuItems(s,edge){const o=meO(),v=ME.v,it=[];const add=(label,ico,cost,err,fn)=>it.push({label,ico,cost,err,fn});
  if(edge){const e=roadErr(o,edge.k);add('Straße zu dieser Kante',BICON.strasse,COST.road,e,()=>buildRoad(o,edge.k));}
  if(s.center){if(s.id!==o)return it;
    [['haus','Haus',BICON.haus,l=>'→ '+(2+l)+' Bewohner/Runde, mehr Platz'],['kas','Kaserne',SWORD,l=>'→ '+(l+1)+' Krieger/Runde'],['werk','Werkstatt',BICON.werk,l=>'→ Waffen +'+(l+1)+' Stärke'+(l?'':', Mauern')]].forEach(([t,name,ico,what])=>{const l=v[t];add((l?name+' ausbauen':name+' bauen')+' '+what(l),ico,l<4?HCOST[t][l+1]:null,homeErr(o,t),()=>homeUp(o,t));});
    const SU=STAGEUP[v.stage+1];if(SU)add('Aufsteigen zu '+STAGE[v.stage+1]+' (+1 Drehung)',STARICON,SU,stageErr(o),()=>{stageUp(o);hint('Du bist jetzt '+STAGE[v.stage]+' und hast eine Drehung verdient',3500);});
    if(v.rot>0)add('Würfel drehen ('+v.rot+')',STARICON,null,null,startRotate);
    return it;}
  const mine=s.own===o,foreign=s.own&&s.own!==o;
  if(resOf(s)&&!foreign)add('Arbeiter hinschicken'+(ME.w?' ('+ME.w+' frei)':''),PICON,null,workErr(o,s),()=>addWorker(o,s));
  if(mine&&s.w>0)add('Arbeiter abziehen ('+s.w+')',MINUS,null,null,()=>{s.w--;ME.w++;syncFig(s);syncFig(ME);});
  if(!s.bt&&!foreign){add('Haus bauen (+1 Bewohner/Runde)',BICON.haus,BCOST.haus,bErr(o,'haus',s),()=>buildOn(o,'haus',s));
    if(s.terr==='wiese')add('Acker anlegen (Nahrung)',BICON.acker,BCOST.acker,bErr(o,'acker',s),()=>buildOn(o,'acker',s));
    for(const t of ['holzf','fischer','bruch'])if(PRODB[t].terr===s.terr)add(BNAME[t]+' (+2 mit Arbeitern)',BICON[t],BCOST[t],bErr(o,t,s),()=>buildOn(o,t,s));}
  if(mine&&!s.wall&&v.werk>0)add('Mauer (+3 Verteidigung)',WALLICON,COST.wall,afford(COST.wall,v.inv)?null:'Braucht '+costTxt(COST.wall),()=>{pay(o,COST.wall);s.wall=true;setFieldBuilding(s);});
  if(ME.u>0||mine&&s.u>0){if(foreign){add('Angreifen mit allen '+ME.u+' Kriegern',SWORD,null,troopErr(o,s),()=>{const d=s.own;const r=sendTroop(o,s);hint(r==='win'?'Feld von '+S[d].v.name+' erobert':'Angriff abgewehrt: dort war mehr Verteidigung',2800);closeMenu();});}
    else{add('Krieger hierher'+(ME.u?' ('+ME.u+' bereit)':''),SWORD,null,troopErr(o,s),()=>sendTroop(o,s));if(mine&&s.u>0)add('Krieger zurück ('+s.u+')',MINUS,null,null,()=>{s.u--;ME.u++;syncFig(s);syncFig(ME);});}}
  return it;}
function openMenu(s,edge,x,y){menuFor=s;menuEdge=edge;menuXY={x,y};renderMenu();}
function renderMenu(){const m=$('#iIT_menu');if(!menuFor){m.hidden=true;return;}const s=menuFor;const [a,b]=fieldInfo(s);const items=menuItems(s,menuEdge);
  m.innerHTML='<div class="iIT_mh"><b>'+a+'</b><small>'+b+'</small></div>'+items.map((t,i)=>'<button class="iIT_mi" data-i="'+i+'"'+(t.err?' disabled':'')+'>'+t.ico+'<span>'+t.label+(t.err?'<small>'+t.err+'</small>':'')+'</span>'+(t.cost?'<em>'+costHtml(t.cost,ME.v.inv)+'</em>':'')+'</button>').join('')+(items.length?'':'<p class="iIT_mn">Hier kannst du gerade nichts tun.</p>');
  m.hidden=false;m.querySelectorAll('[data-i]').forEach(bt=>bt.addEventListener('click',ev=>{ev.stopPropagation();const t=items[+bt.dataset.i];if(t.err)return;t.fn();recalc();refresh();if(menuFor)renderMenu();}));
  const r=m.getBoundingClientRect();let x=menuXY.x+28,y=menuXY.y-r.height/2;if(x+r.width>innerWidth-12)x=menuXY.x-28-r.width;x=Math.max(12,x);y=Math.max(70,Math.min(innerHeight-r.height-12,y));m.style.left=x+'px';m.style.top=y+'px';}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeMenu();});

/* ---------- Eingabe: Tipp ins Feld = Arbeiter hinschicken, sonst die gewählte Bauart ---------- */
function tapTile(s,ptype){
  if(phase==='rotate'){edgeClick(s.id,tapPoint);return;}
  if(phase!=='play'||won)return;const o=meO();
  if(mode==='road'){const r=edgeAt(s,tapPoint);if(!r)return;const e=roadErr(o,r.k);if(e){hint(e,2600);return;}buildRoad(o,r.k);refresh();return;}
  if(s.center&&s.id===o&&mode==='work'){const e=buyErr(o);if(e){hint('Ein Bewohner kostet '+costTxt(buyPrice(o))+'. '+e,2600);return;}buyPerson(o);refresh();return;}
  curQ=quarterAt(s,tapPoint);const e=actErr(s);if(e){hint(e,2600);return;}
  if(mode==='work')addWorker(o,s);
  else if(mode==='pull')pull(o,s);
  else if(mode==='troop'){const d=s.own;const r=sendTroop(o,s);if(r==='win')hint('Feld von '+S[d].v.name+' erobert',2600);else if(r==='lose')hint('Angriff abgewehrt: dort war mehr Verteidigung',2800);}
  else if(mode==='demo'){s.bs=bsOf(s).slice();s.bs[curQ]=null;setFieldBuilding(s);}
  else if(mode==='wall'){pay(o,priceOf(o,'wall'));s.wall=true;setFieldBuilding(s);mode='work';}
  else{buildOn(o,mode,s,curQ);mode='work';}
  recalc();refresh();}
/* ---------- Minimal-Anzeige ---------- */
let hintMsg=null,hintUntil=0,hintT=null;
function hint(msg,ms){if(aiRunning)return;hintMsg=msg;hintUntil=performance.now()+(ms||2600);const t=$('#iIT_phaseText');if(t){t.textContent=msg;$('#iIT_phase').classList.add('iIT_msg');}
  clearTimeout(hintT);hintT=setTimeout(()=>{hintMsg=null;$('#iIT_phase').classList.remove('iIT_msg');renderDock();},ms||2600);}
function gainPulse(keys){setTimeout(()=>keys.forEach(k=>{const el=$('#iIT_r_'+k);if(!el)return;el.classList.remove('iIT_pulse');void el.offsetWidth;el.classList.add('iIT_pulse');}),0);}

/* Neu starten */
$('#iIT_restart').addEventListener('click',()=>location.reload());
/* Kamera: Platz zwischen den Seitenleisten nutzen */
function resize(){const w=innerWidth,h=innerHeight,wide=w>=900;renderer.setSize(w,h,false);camera.aspect=w/h;
  let top=90,bot=h-170;if(!wide){const t=$('#iIT_top'),d=$('#iIT_dock');if(t)top=t.getBoundingClientRect().bottom+4;if(d)bot=d.getBoundingClientRect().top-4;}
  const uw=Math.max(200,wide?w-2*320:w-36),uh=Math.max(200,wide?h-170:bot-top);const vh=THREE.MathUtils.degToRad(camera.fov/2);
  baseDist=(wide?2.55:2.45)/Math.sin(Math.min(Math.atan(Math.tan(vh)*uh/h),Math.atan(Math.tan(vh)*(w/h)*uw/w)));
  camera.setViewOffset(w,h,0,wide?6:Math.round(h/2-(top+bot)/2),w,h);camera.updateProjectionMatrix();}
if(window.ResizeObserver){const ro=new ResizeObserver(()=>{if(innerWidth<900)resize();});['#iIT_top','#iIT_dock'].forEach(q=>{const el=$(q);if(el)ro.observe(el);});}
/* Touch: zwei Finger = zoomen (auseinander/zusammen) und Kamera heben/senken (gemeinsam hoch/runter) */
const touches=new Map();let pinch=null;
canvas.addEventListener('pointerdown',e=>{if(e.pointerType!=='touch')return;touches.set(e.pointerId,{x:e.clientX,y:e.clientY});
  if(touches.size===2){if(ptr){clearTimeout(ptr.lp);if(ptr.mode==='slice')endSlice(true);ptr=null;}canvas.classList.remove('iIT_grabbing');const [a,b]=[...touches.values()];pinch={d:Math.hypot(a.x-b.x,a.y-b.y),y:(a.y+b.y)/2,z:zoom};}});
canvas.addEventListener('pointermove',e=>{if(!touches.has(e.pointerId))return;touches.set(e.pointerId,{x:e.clientX,y:e.clientY});if(!pinch||touches.size<2)return;
  const [a,b]=[...touches.values()];const d=Math.hypot(a.x-b.x,a.y-b.y),my=(a.y+b.y)/2;zoom=THREE.MathUtils.clamp(pinch.z*pinch.d/Math.max(20,d),.6,1.5);orbit(0,(my-pinch.y)*.008);pinch.y=my;});
const tEnd=e=>{touches.delete(e.pointerId);if(touches.size<2)pinch=null;};
canvas.addEventListener('pointerup',tEnd);canvas.addEventListener('pointercancel',tEnd);

/* Rechtsklick / langes Drücken: einen Arbeiter (sonst Krieger) zurückholen, sonst Feldinfo */
function rightTap(s){if(phase==='play'&&!won&&!s.center&&!pullErr(meO(),s)){pull(meO(),s);recalc();refresh();const [a,b]=fieldInfo(s);status(a+' · '+b);return;}showFieldInfo(s);}

/* Zentrum: am Anfang nur ein Zelt mit Lagerfeuer. Wege nach außen entstehen erst durch gebaute Straßen, gepflastert wird ab Dorf */
function makePlaza(s){const g=s.group,vc=s.v.c;
  const base=new THREE.Color(vc).lerp(new THREE.Color('#86b45f'),.35);g.add(mesh(box(.95,.1,.95),M('#'+base.getHexString(),{roughness:.8}),0,.05,0));
  s.mon=new THREE.Group();s.mon.position.y=.1;g.add(s.mon);setMonument(s);
  s.folk=new THREE.Group();s.folk.position.y=.1;g.add(s.folk);addHL(s);}
function setMonument(s){if(!s.mon)return;while(s.mon.children.length)s.mon.remove(s.mon.children[0]);const st=s.v.stage,m=s.mon,vc=s.v.c;
  if(st<1)return;
  if(st===1){const t=mesh(cone(.14,.22,6),M('#e6d7b4',{flatShading:true,roughness:1}),0,.11,0);m.add(t);m.add(mesh(box(.07,.09,.01),M('#5b4636'),0,.045,.115));
    m.add(mesh(cyl(.004,.004,.12,4),M('#5b4636'),0,.27,0));const fl=mesh(box(.08,.045,.004),M(vc),.04,.31,0);m.add(fl);
    const fire=new THREE.Group();fire.position.set(.16,0,.16);for(let i=0;i<6;i++){const a=i/6*Math.PI*2;fire.add(mesh(dodeca(.022),M('#8e877a',{flatShading:true}),Math.cos(a)*.05,.012,Math.sin(a)*.05));}
    const f=mesh(cone(.035,.09,6),M('#ff9a2e',{emissive:col('#ff6a00'),emissiveIntensity:1}),0,.05,0);fire.add(f);f.userData.tick=t=>{f.scale.set(1,.8+.35*Math.sin(t*8),1);};ticks.push(f);m.add(fire);return;}
  if(st>=3)m.add(mesh(cyl(.2,.2,.012,20),M('#ddd3bf',{roughness:1}),0,.006,0));
  if(st<=3){m.add(mesh(cyl(.07,.08,.06,12),M('#c9bfaa'),0,.04,0));m.add(mesh(cyl(.05,.05,.01,12),M('#4d9bd3'),0,.072,0));}
  else if(st===4){m.add(mesh(box(.14,.06,.14),M('#cfc6b4'),0,.04,0));m.add(mesh(box(.08,.2,.08),M('#8b8f97',{metalness:.4,roughness:.4}),0,.17,0));}
  else{m.add(mesh(box(.14,.04,.14),M('#d8d8d8'),0,.02,0));m.add(mesh(box(.08,.42,.08),new THREE.MeshStandardMaterial({color:col('#9cc7e6'),metalness:.6,roughness:.15}),0,.25,0));}
  const p=mesh(cyl(.004,.004,.3,4),M('#5b4636'),.14,.15,-.14);m.add(p);m.add(mesh(box(.1,.055,.004),M(vc),.19,.27,-.14));}

/* Tipp neben den Würfel: in diese Richtung weiterdrehen (links, rechts, oben, unten) */
function emptyTap(x,y){if(busy||phase==='rotate')return;const c=toScreen(new THREE.Vector3(0,0,0));const dx=x-c.x,dy=y-c.y;if(Math.hypot(dx,dy)<40)return;
  stepView(Math.abs(dx)>Math.abs(dy)?(dx<0?'left':'right'):(dy<0?'up':'down'));}

/* Rohstoff-Schild auf jedem Feld: Symbol im Rohstoff-Viertel, bei eigenen Feldern mit Ertrag pro Takt */
const resTags=new Map();const _rp=new THREE.Vector3();
function updateResTags(){if(ME){let el=resTags.get(ME.id);if(!el){el=document.createElement('div');el.className='iIT_rtag iIT_buyTag';labels.appendChild(el);resTags.set(ME.id,el);}
    el.innerHTML='+'+PICON+'<b>'+buyPrice(meO()).gold+'</b>'+RICON.gold;el.classList.toggle('iIT_off',!!buyErr(meO()));}
  S.forEach(f=>{if(f.center)return;const r=resOf(f);let el=resTags.get(f.id);
  if(!r){if(el){el.remove();resTags.delete(f.id);}return;}
  if(!el){el=document.createElement('div');el.className='iIT_rtag';labels.appendChild(el);resTags.set(f.id,el);}
  const y=f.own===meO()?yieldFor(ctx,f,meO(),nets):0;el.innerHTML=RICON[r]+(y?'<b>'+y+'</b>':'');el.title=RES[r];});}
const _wq=new THREE.Quaternion(),_wn=new THREE.Vector3(),_wc=new THREE.Vector3();
function placeResTags(){resTags.forEach((el,id)=>{const f=S[id];if(!f){el.style.display='none';return;}
  f.group.getWorldQuaternion(_wq);_wn.set(0,1,0).applyQuaternion(_wq);f.group.getWorldPosition(_wc);if(_wn.dot(camera.position.clone().sub(_wc))<=0){el.style.display='none';return;}
  if(f.center)_rp.set(0,.5,-.28);else _rp.set(f.terr==='wasser'?0:-.24,.32,f.terr==='wasser'?0:-.24);f.group.localToWorld(_rp);const p=toScreen(_rp);el.style.display='';el.style.left=p.x+'px';el.style.top=p.y+'px';});
  requestAnimationFrame(placeResTags);}
requestAnimationFrame(placeResTags);
const _refresh0=refresh;refresh=function(){_refresh0();updateResTags();};

/* Drehpfeile: im Drehmodus 8 Pfeile um die vordere Seite, je 2 pro äußerer Reihe/Spalte */
function rotClick(c,dir){if(busy)return;if(edgeMark.parent)edgeMark.parent.remove(edgeMark);hovEdge=null;
  const pr=pendingRot;let pv,from=0;
  if(pr&&pr.c.a===c.a&&pr.c.layer===c.layer){pv=pr.pivot;from=pr.net;pendingRot=null;}
  else{if(pr){pendingRot=null;pr.pivot.quaternion.identity();finishPivot(pr.pivot);root.updateMatrixWorld(true);}
    pv=new THREE.Group();root.add(pv);cubies.filter(q=>q.pos[c.a]===c.layer).forEach(q=>pv.attach(q.group));}
  let net=from+dir;const done=Math.abs(net)%4===0;if(done)net=0;busy=true;
  S.forEach(q=>{if(!q.hl)return;const mv=q.p[c.a]===c.layer&&!q.center;q.hl.visible=mv;if(mv)q.hl.material.color.copy(col('#3fd0ff'));});
  const a0=from*Math.PI/2,a1=(from+dir)*Math.PI/2;
  tween(320,k=>pv.quaternion.setFromAxisAngle(AX[c.a],a0+(a1-a0)*easeIO(k)),()=>{
    if(done){pv.quaternion.identity();finishPivot(pv);busy=false;refresh();hint('Zurück zur Ausgangslage');return;}
    pendingRot={c,net,pivot:pv,text:previewText(c,net)};busy=false;refresh();});}
let ARG=null;const rArrows=[];const _f=new THREE.Vector3(),_r=new THREE.Vector3(),_ap=new THREE.Vector3();
for(let i=0;i<12;i++){const b=document.createElement('button');b.className='iIT_rarrow';b.id='iIT_ra_'+i;b.setAttribute('aria-label','Scheibe drehen');b.hidden=true;
  b.addEventListener('click',e=>{e.stopPropagation();const d=b._def;if(d)rotClick(d.c,d.dir);});labels.appendChild(b);rArrows.push(b);}
function placeRotArrows(){const show=phase==='rotate'&&!busy&&!won;
  if(!show){rArrows.forEach(b=>b.hidden=true);requestAnimationFrame(placeRotArrows);return;}
  _f.set(0,0,1).applyQuaternion(camera.quaternion);_r.set(1,0,0).applyQuaternion(camera.quaternion);
  const F=nearestAx(_f),Rv=nearestAx(_r,F),U=new THREE.Vector3().crossVectors(F,Rv);
  const ix=v=>Math.abs(v.x)>.5?0:Math.abs(v.y)>.5?1:2,sg=v=>Math.sign(v.x+v.y+v.z);
  if(!ARG){const c0=PL[0],nb=nbrs(c0,indexOf(S))[0];ARG={D:anchorOf(c0,0).length(),sp:nb?anchorOf(nb,0).distanceTo(anchorOf(c0,0)):1};}const D=ARG.D,sp=ARG.sp,out=1.5*sp+.42;
  const aU=ix(U),sU=sg(U),aR=ix(Rv),sR=sg(Rv);
  const defs=[
    {p:[U,sp,Rv,-out],c:{a:aU,layer:sU},dir:-sU,g:'←'},{p:[U,sp,Rv,out],c:{a:aU,layer:sU},dir:sU,g:'→'},
    {p:[U,-sp,Rv,-out],c:{a:aU,layer:-sU},dir:-sU,g:'←'},{p:[U,-sp,Rv,out],c:{a:aU,layer:-sU},dir:sU,g:'→'},
    {p:[Rv,sp,U,out],c:{a:aR,layer:sR},dir:-sR,g:'↑'},{p:[Rv,sp,U,-out],c:{a:aR,layer:sR},dir:sR,g:'↓'},
    {p:[Rv,-sp,U,out],c:{a:aR,layer:-sR},dir:-sR,g:'↑'},{p:[Rv,-sp,U,-out],c:{a:aR,layer:-sR},dir:sR,g:'↓'},
    {p:[U,0,Rv,-out],c:{a:aU,layer:0},dir:-sU,g:'←'},{p:[U,0,Rv,out],c:{a:aU,layer:0},dir:sU,g:'→'},
    {p:[Rv,0,U,out],c:{a:aR,layer:0},dir:-sR,g:'↑'},{p:[Rv,0,U,-out],c:{a:aR,layer:0},dir:sR,g:'↓'}];
  defs.forEach((d,i)=>{const b=rArrows[i];_ap.copy(F).multiplyScalar(D).addScaledVector(d.p[0],d.p[1]).addScaledVector(d.p[2],d.p[3]);const q=toScreen(_ap);
    b._def=d;if(b.textContent!==d.g)b.textContent=d.g;b.hidden=false;b.style.left=q.x+'px';b.style.top=q.y+'px';});
  requestAnimationFrame(placeRotArrows);}
requestAnimationFrame(placeRotArrows);

/* Mittelscheiben drehen mit, aber die Zentren (Mittelfelder) bleiben immer auf ihrer Seite */
const isCenterCubie=q=>q.pos.filter(x=>x===0).length>=2;
const slices=(q,a,layer)=>q.pos[a]===layer&&!isCenterCubie(q);
function rotateSt(st,a,layer,d){for(const s of st)if(s.p[a]===layer&&!s.center){s.p=rv(s.p,a,d);s.n=rv(s.n,a,d);}return st;}

/* ================= Wirtschaft 0.5: Gold, Feld-Stufen, Felder kaufen ================= */
const FTYPE={wald:'holzf',berg:'bruch',wasser:'fischer',wiese:'acker',gold:'bruch',eisen:'bruch',lehm:'bruch'};
const upPrice=L=>({gold:[0,3,6,10,15][L],holz:[0,2,4,6,8][L]});
const fieldPrice=o=>({gold:6+3*(S[o].v.boughtF||0)});
function upErr(o,f){if(f.center)return null;if(f.own!==o)return 'Nicht dein Feld';const L=(f.lv||0)+1;if(L>4)return 'Voll ausgebaut';
  if(L>S[o].v.stage)return 'Stufe '+L+' geht erst mit dem nächsten Ausbau des Zentrums';if(!(S[o].w>0))return 'Kein freier Bewohner: '+(TOUCH?'tipp':'klick')+' aufs Zentrum und kauf einen ('+buyPrice(o).gold+' Gold)';
  const c=upPrice(L);return afford(c,S[o].v.inv)?null:'Ausbau auf Stufe '+L+' braucht '+costTxt(c);}
function upField(o,f){const L=(f.lv||0)+1;pay(o,upPrice(L));S[o].w--;f.lv=L;f.w=L;setFieldBuilding(f);syncFig(S[o]);if(o===meO()&&!aiRunning)walkFig(S[o],f,()=>syncFig(f));else syncFig(f);}
function buyFieldErr(o,f){if(f.center)return 'Zentren kann man nicht kaufen';if(f.own===o)return null;if(f.own)return 'Gehört '+S[f.own].v.name+'. Erobern geht nur mit Kriegern über eine Straße';
  const adj=nbrs(f,ctx.idx).filter(q=>q.own===o||q.id===o);if(!adj.length)return 'Kaufen kannst du nur Felder, die an dein Gebiet grenzen';
  if(S[o].v.stage<2&&!adj.some(q=>same(q,f)))return 'Über die Würfelkante geht es erst ab '+STAGE[2];
  const c=fieldPrice(o);return afford(c,S[o].v.inv)?null:'Dieses Feld kostet '+costTxt(c);}
function buyField(o,f){pay(o,fieldPrice(o));S[o].v.boughtF=(S[o].v.boughtF||0)+1;f.own=o;f.conq=true;f.lv=f.lv||0;claimPos(f,o);(f.rs||[]).forEach(r=>r.o=o);setFieldBuilding(f);recalc();}
/* Ertrag: Stufe × Rohstoff (Straße verdoppelt) und Stufe × Gold */
function yieldParts(c,f,o,n){const st=c.st[f.id];return{w:st.lv||0,road:roadAt(c,o,f,n)?1:0,prod:0};}
function yieldFor(c,f,o,n){const st=c.st[f.id];if(st.center||st.own!==o||!st.lv)return 0;return st.lv*(roadAt(c,o,f,n)?2:1);}
function tick(){if(won||phase!=='play'||busy||playingRots)return;round++;tAcc=0;const myGain={};
  S.forEach(f=>{if(f.center||f.own==null||!OWN.includes(f.own)||!f.lv)return;const y=yieldFor(ctx,f,f.own,nets);const r=resOf(f);const v=S[f.own].v;v.inv[r]=(v.inv[r]||0)+y;
    if(f.own===meO()){myGain[r]=1;floatAt(anchorOf(f,.25),'+'+y+RICON[r],'#2e5a2e');}});
  OWN.forEach(o=>{const v=S[o].v;const g=goldOf(o);v.inv.gold=(v.inv.gold||0)+g;const k=Math.min(v.kas,v.inv.nahrung);v.inv.nahrung-=k;S[o].u+=k;syncFig(S[o]);
    if(o===meO()){myGain.gold=1;floatAt(anchorOf(S[o],.45),'+'+g+RICON.gold+(k?' +'+k+SWORD:''),'#8a6a00');}});
  const notes=[];AIS.forEach(pl=>{const t=aiAct(pl.id);if(t)notes.push(t);});aiLog=notes;
  recalc();checkEnd();refresh();readyCheck();gainPulse(Object.keys(myGain));if(rotQ.length)playRots();}
/* Felder sehen: je Stufe eine Hütte in einem Viertel */
function setFieldBuilding(f){if(f.bObj)f.group.remove(f.bObj);f.bObj=null;const g=new THREE.Group();const lv=f.lv||0,t=FTYPE[f.terr];
  [1,2,3,0].slice(0,lv).forEach(qi=>{const b=makeBuilding(t,1);let [x,z]=QPOS[qi];if(qi===0&&f.terr!=='wasser'){x+=.1;z+=.1;}
    if(t==='acker'){b.scale.set(.42,1,.42);}else b.scale.setScalar(.62);b.position.set(x,.1,z);g.add(b);});
  if(f.wall){[[0,.45],[0,-.45],[.45,0],[-.45,0]].forEach(([x,z])=>{const w=mesh(box(x?.04:.86,.08,x?.86:.04),M('#9b9384',{flatShading:true}),x,.15,z);g.add(w);});}f.group.add(g);f.bObj=g;}
function actErr(s){const o=meO();if(mode==='troop')return troopErr(o,s);
  if(mode==='wall'){if(s.own!==o||s.center)return 'Nur auf deinen Feldern';if(s.wall)return 'Hier steht schon eine Mauer';const pc=priceOf(o,'wall');return afford(pc,ME.v.inv)?null:'Braucht '+costTxt(pc);}
  if(s.center)return s.id===o?buyErr(o):'Fremdes Zentrum';return s.own===o?upErr(o,s):buyFieldErr(o,s);}
function tapTile(s,ptype){
  if(phase==='rotate'){edgeClick(s.id,tapPoint);return;}
  if(phase!=='play'||won)return;const o=meO();
  if(mode==='road'){const r=edgeAt(s,tapPoint);if(!r)return;const e=roadErr(o,r.k);if(e){hint(e,2600);return;}buildRoad(o,r.k);mode='work';refresh();return;}
  if(mode==='work'){if(sel===s.id){doSel();return;}sel=s.id;refresh();return;}
  const e=actErr(s);if(e){hint(e,3200);fbAt(s,e,true);return;}
  if(mode==='troop'){const d=s.own;const r=sendTroop(o,s);if(r==='win')hint('Feld von '+S[d].v.name+' erobert',2600);else if(r==='lose')hint('Angriff abgewehrt: dort war mehr Verteidigung',2800);}
  else if(mode==='wall'){pay(o,priceOf(o,'wall'));s.wall=true;setFieldBuilding(s);mode='work';}
  else if(s.own===o){upField(o,s);fbAt(s,'Stufe '+s.lv+' ✓');}else{buyField(o,s);fbAt(s,'Gekauft ✓');}
  recalc();refresh();}
function rightTap(s){showFieldInfo(s);}
function fieldInfo(s){const o=meO();
  if(s.center)return [s.v.name+(OWN.includes(s.id)?(s.id===o?' · dein Zentrum':' · Zentrum der KI'):' · frei'),s.id===o?'Ausbau: '+STAGE[s.v.stage]+' · Klick kauft einen Bewohner ('+buyPrice(o).gold+' Gold)':'Zentren drehen nie mit und sind nicht eroberbar'];
  const r=resOf(s),lv=s.lv||0;const head=TERR[s.terr].name+' · Stufe '+lv+'/4'+(s.own!=null?' · '+S[s.own].v.name+(s.own===o?' (dir)':''):' · frei');
  if(s.own===o){const y=yieldFor(ctx,s,o,nets);const nx=lv<4?' · Ausbau auf '+(lv+1)+': '+costTxt(upPrice(lv+1))+' + 1 Bewohner':'';return [head,'Ertrag: '+y+' '+RES[r]+' + '+lv+' Gold pro Takt'+(roadAt(ctx,o,s,nets)?' (Straße ×2)':'')+nx];}
  if(s.own)return [head,'Erobern geht nur mit Kriegern über eine Straße'];
  const e=buyFieldErr(o,s);return [head,e||'Kaufen: '+costTxt(fieldPrice(o))];}
/* Schilder auf den Feldern: Rohstoff + Stufe, darunter die Aktion, die ein Tipp auslöst (grün = geht, grau = fehlt was) */
/* Schilder: nur Rohstoff + Stufe, dazu ein kleiner Punkt, wenn hier gerade etwas geht. Details zeigt das Auswahl-Panel */
function canHere(f){const o=meO();if(f.own===o)return !upErr(o,f);if(!f.own&&!f.center)return !buyFieldErr(o,f);return false;}
function updateResTags(){if(ME){let el=resTags.get(ME.id);if(!el){el=document.createElement('div');el.className='iIT_rtag iIT_buyTag';labels.appendChild(el);resTags.set(ME.id,el);}
    const ok=!buyErr(meO())&&phase==='play';el.innerHTML=ok?'<div class="iIT_top"><em class="iIT_can">+</em>'+PICON+'</div>':'';el.style.visibility=ok?'':'hidden';}
  S.forEach(f=>{if(f.center)return;const r=resOf(f);let el=resTags.get(f.id);if(!r){if(el){el.remove();resTags.delete(f.id);}return;}
    if(!el){el=document.createElement('div');el.className='iIT_rtag';labels.appendChild(el);resTags.set(f.id,el);}
    const lv=f.lv||0,can=phase==='play'&&mode==='work'&&canHere(f);
    el.innerHTML='<div class="iIT_top'+(sel===f.id?' iIT_selTag':'')+'">'+(f.terr==='wiese'?BICON.acker:RICON[r])+(lv?'<i class="iIT_lv">'+'●'.repeat(lv)+'<u>'+'●'.repeat(4-lv)+'</u></i>':'')+(can?'<em class="iIT_can">'+(f.own===meO()?'↑':'+')+'</em>':'')+'</div>';el.title=RES[r];});}
/* Auswahl-Panel: Feld antippen = auswählen, Knopf (oder nochmal tippen) = ausführen */
let sel=null;
function selPanel(){let p=$('#iIT_selp');if(!p){p=document.createElement('div');p.id='iIT_selp';p.className='iIT_panel';$('#iIT_dock').insertBefore(p,$('#iIT_cards'));}return p;}
function renderSel(){const p=selPanel();if(sel==null||phase!=='play'||mode!=='work'){p.hidden=true;return;}const s=S[sel],o=meO(),v=ME.v;p.hidden=false;
  let title,info,btn='',err=null,act=null;
  if(s.center){title=s.id===o?'Dein Zentrum · '+STAGE[v.stage]:s.v.name+' (Zentrum)';info=s.id===o?'+'+goldOf(o)+' Gold pro Takt · '+ME.w+' Bewohner frei':'Zentren kann man nicht erobern';
    if(s.id===o){err=buyErr(o);act='buy';btn='+1 Bewohner kaufen · '+costHtml(buyPrice(o),v.inv);}}
  else{const r=resOf(s),lv=s.lv||0;title=TERR[s.terr].name+' · Stufe '+lv+'/4';
    if(s.own===o){const y=yieldFor(ctx,s,o,nets);info=lv?'Bringt +'+y+' '+RES[r]+' und +'+lv+' Gold pro Takt'+(roadAt(ctx,o,s,nets)?' (Straße ×2)':''):'Noch nicht ausgebaut: Stufe 1 bringt +1 '+RES[r]+' und +1 Gold pro Takt';
      if(lv<4){err=upErr(o,s);act='up';btn='Ausbauen auf Stufe '+(lv+1)+' · '+PICON+'1 '+costHtml(upPrice(lv+1),v.inv);}else info+=' · voll ausgebaut';}
    else if(s.own){title+=' · '+S[s.own].v.name;info='Erobern geht nur mit Kriegern über eine Straße';}
    else{info='Freies Feld';err=buyFieldErr(o,s);act='buyf';btn='Feld kaufen · '+costHtml(fieldPrice(o),v.inv);}}
  p.innerHTML='<button class="iIT_x" id="iIT_selx" aria-label="Schließen">×</button><b>'+title+'</b><small>'+info+'</small>'+(btn?'<button class="iIT_btn" id="iIT_selgo"'+(err?' disabled':'')+'>'+btn+'</button>'+(err?'<em class="iIT_why">'+err+'</em>':''):'');
  $('#iIT_selx').addEventListener('click',()=>{sel=null;refresh();});
  const go=$('#iIT_selgo');if(go)go.addEventListener('click',()=>doSel());}
function doSel(){if(sel==null)return;const s=S[sel],o=meO();
  if(s.center&&s.id===o){if(buyErr(o))return;buyPerson(o);fbAt(s,'+1 Bewohner ✓');}
  else if(s.own===o){if(upErr(o,s))return;upField(o,s);fbAt(s,'Stufe '+s.lv+' ✓');}
  else if(!s.own){if(buyFieldErr(o,s))return;buyField(o,s);fbAt(s,'Gekauft ✓');}
  recalc();refresh();}
/* KI 0.5 */
function aiAct(o){aiRunning=true;const v=S[o].v,home=S[o],w=needW(o),did=[];
  try{
    if(!stageErr(o)){stageUp(o);did.push(STAGE[v.stage]);}
    const SU=STAGEUP[v.stage+1]||{};const keep=Math.floor((SU.gold||0)*.6);
    for(let t=0;t<2&&home.w<1&&!buyErr(o)&&v.inv.gold-buyPrice(o).gold>=keep*.5;t++)buyPerson(o);
    for(let t=0;t<2;t++){let best=null,bv=0;S.forEach(f=>{if(f.center||f.own!==o||upErr(o,f))return;if(v.inv.gold-upPrice((f.lv||0)+1).gold<keep*.5)return;
        const sc=(w[resOf(f)]||1)*(roadAt(ctx,o,f,nets)?2:1)/(1+(f.lv||0)*.4)+Math.random()*.2;if(sc>bv){bv=sc;best=f;}});if(!best)break;upField(o,best);did.push(TERR[best.terr].name+' Stufe '+best.lv);}
    if(v.inv.gold-fieldPrice(o).gold>=keep){let best=null,bv=0;S.forEach(f=>{if(f.center||f.own||buyFieldErr(o,f))return;const sc=(w[resOf(f)]||1)+Math.random()*.3;if(sc>bv){bv=sc;best=f;}});if(best){buyField(o,best);did.push('kauft '+TERR[best.terr].name);}}
    if(v.markt){const ks=['holz','stein','nahrung'];for(let t=0;t<3;t++){const give=ks.reduce((a,k)=>(v.inv[k]||0)>(v.inv[a]||0)?k:a,ks[0]);const get=Object.keys(SU).find(k=>k!=='gold'&&(v.inv[k]||0)<SU[k]&&k!==give)||(v.kas?'nahrung':null);
      if(!get||(v.inv[give]||0)<15+rateOf(o)||tradeErr(o,give,get))break;trade(o,give,get);}}
    if(roadsLeft(o)>0&&Math.random()<.5){let best=null,bv=.4;S.forEach(f=>{if(f.own!==o&&f.id!==o)return;nbrs(f,ctx.idx).forEach(q=>{const k={f:f.id,q:q.id};if(roadErr(o,k))return;
        let sc=(q.own&&q.own!==o&&!q.center?2:0)+(q.own===o?(resOf(q)?(w[resOf(q)]||1)*(q.lv||0)*.5:0):0)+Math.random()*.3;if(sc>bv){bv=sc;best=k;}});});
      if(best){buildRoad(o,best);did.push('Straße');}}
    if(home.u>0){let tgt=null;S.forEach(f=>{if(tgt||f.center||!f.own||f.own===o||troopErr(o,f))return;const D=(f.u||0)*strOf(f.own)+(f.w||0)*.5+(f.wall?3:0);if(home.u*strOf(o)>D+1)tgt=f;});
      if(tgt){const d=tgt.own;if(sendTroop(o,tgt)==='win'){did.push('erobert ein Feld von '+S[d].v.name);if(d===meO())setTimeout(()=>hint(v.name+' hat dir ein Feld abgenommen!',3500),400);}}}
    if(v.rot>0&&!rotQ.some(r=>r.o===o))queueAiRot(o);
  }finally{aiRunning=false;}
  return did.length?v.name+' (KI): '+did.join(', '):null;}

/* Sichtbare Rückmeldung am angetippten Feld */
function fbAt(s,txt,bad){const el=document.createElement('div');el.className='iIT_fb'+(bad?' iIT_bad':'');el.innerHTML='<span>'+txt+'</span>';labels.appendChild(el);
  const p=toScreen(anchorOf(s,.3));el.style.left=p.x+'px';el.style.top=p.y+'px';setTimeout(()=>el.remove(),bad?2600:1500);}
