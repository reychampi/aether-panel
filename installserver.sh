#!/bin/bash

# ============================================================
# AETHER NEBULA v4.1 - RESTORATION UPDATE
# Fixes missing Game Settings + Adds Visual Login Screen
# ============================================================

set -e
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${MAGENTA}=================================================${NC}"
echo -e "${MAGENTA}   🌌 NEBULA v4.1 (RESTAURADO + LOGIN)           ${NC}"
echo -e "${MAGENTA}=================================================${NC}"

# 1. MANTENEMOS BACKEND MODULAR (Solo actualizamos server.js y mc_manager.js por seguridad)
mkdir -p /opt/aetherpanel/public

# SERVER.JS (Con Login Route)
cat <<EOF > /opt/aetherpanel/server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const multer = require('multer');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const MCManager = require('./mc_manager');
const Market = require('./modules/marketplace');
const Updater = require('./modules/updater');
const Worlds = require('./modules/worlds');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const apiLimiter = rateLimit({ windowMs: 15*60*1000, max: 100 });
app.use('/api/', apiLimiter);

const mcServer = new MCManager(io);
const market = new Market(mcServer.basePath);
const updater = new Updater();
const worlds = new Worlds(mcServer.basePath);

const storage = multer.diskStorage({ destination: (req,file,cb)=>cb(null, mcServer.basePath), filename: (req,file,cb)=>cb(null, file.originalname) });
const upload = multer({ storage: storage });

const auth = (req, res, next) => {
    const cfg = mcServer.getLabsConfig();
    if(cfg.password && cfg.password !== '') {
        if(req.headers['x-auth'] !== cfg.password) return res.status(403).json({error: 'Acceso denegado'});
    }
    next();
};

// API
app.post('/api/login', (req, res) => {
    const cfg = mcServer.getLabsConfig();
    if(!cfg.password || cfg.password === req.body.password) res.json({success:true});
    else res.status(403).json({error: 'Contraseña incorrecta'});
});

app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.get('/api/stats', async (req, res) => res.json(await mcServer.getPerformance()));
app.post('/api/power/:action', auth, async (req, res) => {
    try { if(mcServer[req.params.action]) { await mcServer[req.params.action](); res.json({success:true}); } } catch(e){res.status(500).json({error:e.message});}
});

app.get('/api/config', (req, res) => res.json(mcServer.getConfig()));
app.post('/api/config', auth, (req, res) => { mcServer.saveConfig(req.body); res.json({success:true}); });
app.post('/api/game-settings', auth, (req, res) => { mcServer.updateServerProperties(req.body); res.json({success:true}); });

app.post('/api/install', auth, async (req, res) => { try{await mcServer.installJar(req.body);res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });
app.get('/api/versions/:type', async (req, res) => { try{res.json(await mcServer.fetchVersions(req.params.type));}catch(e){res.status(500).json([]);} });

app.get('/api/market/search', async (req, res) => res.json(await market.search(req.query.q, req.query.loader)));
app.post('/api/market/install', auth, async (req, res) => { try{await market.install(req.body.url, req.body.filename);res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });

app.post('/api/worlds/reset', auth, (req, res) => { try{worlds.resetDimension(req.body.dim);res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });
app.get('/api/update/check', async (req, res) => res.json(await updater.check()));
app.post('/api/update/pull', auth, async (req, res) => { try{await updater.pull();res.json({success:true});setTimeout(()=>process.exit(0),1000);}catch(e){res.status(500).json({error:e.message});} });

app.post('/api/upload', auth, upload.single('file'), (req, res) => res.json({success: true}));
app.get('/api/files/list', (req, res) => res.json(mcServer.listFiles()));
app.post('/api/files/read', auth, (req, res) => res.send(mcServer.readFile(req.body.file)));
app.post('/api/files/save', auth, (req, res) => { mcServer.saveFile(req.body.file, req.body.content); res.json({success:true}); });

app.get('/api/players', (req, res) => res.json(mcServer.players));
app.post('/api/players/action', auth, (req, res) => { mcServer.playerAction(req.body.action, req.body.player); res.json({success:true}); });

app.get('/api/labs/info', (req, res) => res.json(mcServer.getLabsConfig()));
app.post('/api/labs/set-auth', (req, res) => { mcServer.setLabsAuth(req.body.password); res.json({success:true}); });
app.post('/api/labs/set-discord', auth, (req, res) => { mcServer.setDiscord(req.body.url); res.json({success:true}); });
app.post('/api/labs/set-schedule', auth, (req, res) => { mcServer.setSchedule(req.body.hours); res.json({success:true}); });
app.post('/api/labs/wipe', auth, async (req, res) => { await mcServer.labsWipe(); res.json({success:true}); });
app.post('/api/labs/backup', auth, async (req, res) => { await mcServer.createBackup(); res.json({success:true}); });

io.on('connection', (s) => {
    s.emit('logs', mcServer.getRecentLogs());
    s.on('command', (c) => mcServer.sendCommand(c));
});

server.listen(3000, () => console.log('Nebula v4.1 Online'));
EOF

# 2. FRONTEND RESTAURADO (HTML)
cat <<EOF > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nebula v4.1</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;500;700;900&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css" rel="stylesheet">
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.6/ace.js"></script>
</head>
<body>
    <div id="login-screen" class="login-overlay">
        <div class="login-box">
            <div class="brand-lg"><i class="ri-shining-2-fill ico-lg"></i> NEBULA</div>
            <p>Introduce tu contraseña de acceso</p>
            <input type="password" id="login-pass" placeholder="Contraseña..." onkeypress="if(event.key==='Enter') tryLogin()">
            <button class="btn pr full" onclick="tryLogin()">Entrar</button>
        </div>
    </div>

    <div class="app" id="app-ui" style="filter:blur(5px); pointer-events:none;">
        <aside class="sidebar">
            <div class="brand"><i class="ri-shining-2-fill ico"></i> NEBULA <span class="ver">4.1</span></div>
            <nav>
                <div class="cat">CORE</div>
                <button onclick="nav('console')" class="n-btn active"><i class="ri-terminal-box-fill"></i> Consola</button>
                <button onclick="nav('files')" class="n-btn"><i class="ri-folder-5-fill"></i> Archivos</button>
                <button onclick="nav('market')" class="n-btn"><i class="ri-store-2-fill"></i> Mercado</button>
                <div class="cat">GESTIÓN</div>
                <button onclick="nav('worlds')" class="n-btn"><i class="ri-earth-fill"></i> Mundos</button>
                <button onclick="nav('install')" class="n-btn"><i class="ri-cloud-windy-fill"></i> Versiones</button>
                <div class="cat">CONFIG</div>
                <button onclick="nav('game')" class="n-btn"><i class="ri-settings-4-fill"></i> Juego</button>
                <button onclick="nav('hardware')" class="n-btn"><i class="ri-cpu-line"></i> Hardware</button>
                <button onclick="nav('labs')" class="n-btn labs-btn"><i class="ri-flask-fill"></i> Labs</button>
            </nav>
            <div class="foot">
                <button class="theme-sw" onclick="togTheme()"><i class="ri-moon-line" id="t-ico"></i></button>
                <div id="bdg" class="bdg off">OFFLINE</div>
            </div>
        </aside>

        <main>
            <header><h2 id="pg-t">Consola</h2><div class="acts"><button class="btn go" onclick="pwr('start')">▶</button><button class="btn wa" onclick="pwr('restart')">↻</button><button class="btn st" onclick="pwr('stop')">⏹</button></div></header>

            <div id="v-console" class="view active">
                <div id="ovl" class="ovl"><div class="box"><h3>Trabajando...</h3><div class="trk"><div id="bar"></div></div><span id="pct">0%</span></div></div>
                <div class="term"><div id="logs"></div><div class="inp-w"><input id="cmd" placeholder="> Comando..."></div></div>
            </div>

            <div id="v-game" class="view">
                <div class="grid-2">
                    <div class="card">
                        <h3>General</h3>
                        <div class="inp-g"><label>Nombre Servidor (MOTD)</label><input id="g-motd"></div>
                        <div class="inp-g"><label>Máximo Jugadores</label><input type="number" id="g-max"></div>
                        <div class="inp-g"><label>Puerto</label><input type="number" id="g-port" placeholder="25565"></div>
                    </div>
                    <div class="card">
                        <h3>Mundo</h3>
                        <div class="inp-g"><label>Level Name</label><input id="g-level"></div>
                        <div class="inp-g"><label>Seed</label><input id="g-seed"></div>
                        <div class="inp-g"><label>View Distance</label><input type="number" id="g-view"></div>
                    </div>
                    <div class="card">
                        <h3>Reglas</h3>
                        <div class="sw-row"><span>Crackeado</span><input type="checkbox" id="g-crack" class="tg"></div>
                        <div class="sw-row"><span>PVP</span><input type="checkbox" id="g-pvp" class="tg"></div>
                        <div class="sw-row"><span>Hardcore</span><input type="checkbox" id="g-hc" class="tg"></div>
                        <div class="sw-row"><span>Vuelo (Fly)</span><input type="checkbox" id="g-fly" class="tg"></div>
                        <div class="sw-row"><span>Cmd Blocks</span><input type="checkbox" id="g-cmd" class="tg"></div>
                    </div>
                    <div class="card">
                        <h3>Avanzado</h3>
                        <div class="sw-row"><span>Monstruos</span><input type="checkbox" id="g-monsters" class="tg"></div>
                        <div class="sw-row"><span>NPCs</span><input type="checkbox" id="g-npcs" class="tg"></div>
                        <div class="sw-row"><span>Nether</span><input type="checkbox" id="g-nether" class="tg"></div>
                        <div class="sw-row"><span>Whitelist</span><input type="checkbox" id="g-white" class="tg"></div>
                        <div class="inp-g"><label>Dificultad</label><select id="g-diff"><option value="peaceful">Pacífico</option><option value="easy">Fácil</option><option value="normal">Normal</option><option value="hard">Difícil</option></select></div>
                    </div>
                </div>
                <button class="btn pr full" onclick="saveG()">Guardar Todo</button>
            </div>

            <div id="v-market" class="view">
                <div class="card">
                    <h3>Marketplace (Modrinth)</h3>
                    <div class="flex-row"><input id="m-q" placeholder="Buscar..."><button class="btn pr" onclick="searchM()">Buscar</button></div>
                    <div id="m-res" class="m-grid"></div>
                </div>
            </div>

            <div id="v-files" class="view"><div class="card"><h3>Archivos</h3><div class="upl-zone" onclick="document.getElementById('f-inp').click()"><span>Subir</span><input type="file" id="f-inp" hidden></div><div id="f-list" class="file-grid" style="margin-top:15px"></div></div></div>
            
            <div id="v-install" class="view"><div class="card"><h3>Versiones</h3><div class="row-grid"><select id="ldr" onchange="getV()"><option value="paper">Paper</option><option value="vanilla">Vanilla</option><option value="forge">Forge</option><option value="fabric">Fabric</option></select><select id="ver" disabled></select></div><button class="btn pr full" onclick="inst()">Instalar</button></div></div>
            
            <div id="v-worlds" class="view"><div class="grid-2"><div class="card danger-zone"><h3>Nether</h3><button class="btn st full" onclick="resetDim('nether')">Reset</button></div><div class="card danger-zone"><h3>The End</h3><button class="btn st full" onclick="resetDim('end')">Reset</button></div></div></div>
            
            <div id="v-hardware" class="view"><div class="card"><h3>Aikar Flags</h3><input type="checkbox" id="h-aikar" class="tg"><br><h3>RAM: <span id="rv">4G</span></h3><input type="range" id="h-ram" min="1" max="16" oninput="document.getElementById('rv').innerText=this.value+'G'"><button class="btn pr full" onclick="saveH()">Aplicar</button></div></div>
            
            <div id="v-labs" class="view"><div class="grid-2"><div class="card"><h3>Auto-Update</h3><button class="btn sc" onclick="chkUp()">Check Updates</button><p id="u-msg"></p></div><div class="card"><h3>Auth</h3><input type="password" id="l-pass"><button class="btn sc" onclick="saveA()">Set Pass</button></div><div class="card danger"><h3>Danger</h3><button class="btn st full" onclick="wipe()">WIPE</button></div></div></div>

        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# 3. CSS (STYLE)
cat <<EOF > /opt/aetherpanel/public/style.css
:root { --bg:#09090b; --sb:#121215; --cd:#18181b; --bd:#27272a; --tx:#e4e4e7; --dim:#888; --acc:#7c3aed; --gr:#10b981; --rd:#ef4444; --yl:#f59e0b; --font:'Outfit',sans-serif; }
body.light { --bg:#f8fafc; --sb:#fff; --cd:#fff; --bd:#e2e8f0; --tx:#0f172a; --dim:#64748b; --acc:#4f46e5; }
* { box-sizing:border-box; transition:0.2s; } body { margin:0; background:var(--bg); color:var(--tx); font-family:var(--font); height:100vh; overflow:hidden; }
.app { display:flex; height:100%; } .sidebar { width:250px; background:var(--sb); border-right:1px solid var(--bd); padding:20px; display:flex; flex-direction:column; }
.brand { font-weight:800; font-size:1.2rem; margin-bottom:30px; display:flex; align-items:center; gap:10px; } .ico { color:var(--acc); font-size:1.5rem; } .ver { font-size:0.7rem; background:rgba(124,58,237,0.1); color:var(--acc); padding:2px 5px; border-radius:4px; }
.cat { font-size:0.7rem; font-weight:700; color:var(--dim); margin:15px 0 5px 0; }
.n-btn { width:100%; text-align:left; padding:10px; background:transparent; border:none; color:var(--dim); border-radius:8px; cursor:pointer; font-weight:600; display:flex; gap:10px; }
.n-btn:hover { background:var(--bd); color:var(--tx); } .n-btn.active { background:var(--acc); color:#fff; }
.labs-btn { color:var(--rd); } .foot { margin-top:auto; padding-top:20px; border-top:1px solid var(--bd); display:flex; justify-content:space-between; align-items:center; }
.theme-sw { border:1px solid var(--bd); background:transparent; border-radius:6px; padding:5px; cursor:pointer; color:var(--tx); }
.bdg { padding:5px 10px; border-radius:6px; font-weight:800; font-size:0.7rem; } .off { background:rgba(239,68,68,0.15); color:var(--rd); } .on { background:rgba(16,185,129,0.15); color:var(--gr); }
main { flex:1; padding:30px; display:flex; flex-direction:column; } header { display:flex; justify-content:space-between; margin-bottom:20px; }
.btn { padding:8px 20px; border-radius:6px; border:none; font-weight:700; cursor:pointer; color:#fff; } .go{background:var(--gr)} .st{background:var(--rd)} .pr{background:var(--acc)} .sc{background:var(--bd);color:var(--tx)} .full{width:100%;margin-top:10px}
.view { display:none; flex-direction:column; height:100%; } .view.active { display:flex; animation:fadeIn 0.2s ease; } @keyframes fadeIn{from{opacity:0}to{opacity:1}}
.term { flex:1; background:#0a0a0c; border-radius:10px; border:1px solid var(--bd); display:flex; flex-direction:column; overflow:hidden; }
#logs { flex:1; padding:15px; overflow-y:auto; font-family:'monospace'; font-size:0.85rem; white-space:pre-wrap; }
.inp-w { border-top:1px solid var(--bd); padding:10px; background:#111; } #cmd { width:100%; background:transparent; border:none; color:#fff; outline:none; font-family:'monospace'; }
.card { background:var(--cd); border:1px solid var(--bd); border-radius:14px; padding:20px; margin-bottom:20px; overflow:hidden; }
.grid-2 { display:grid; grid-template-columns:1fr 1fr; gap:20px; overflow-y:auto; }
input, select { width:100%; padding:10px; background:var(--bg); border:1px solid var(--bd); border-radius:6px; color:var(--tx); outline:none; margin-bottom:10px; }
.upl-zone { border:2px dashed var(--bd); padding:40px; text-align:center; border-radius:12px; cursor:pointer; } .upl-zone:hover { border-color:var(--acc); }
.m-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(250px, 1fr)); gap:10px; margin-top:15px; max-height:400px; overflow-y:auto; }
.m-item { background:var(--bg); padding:10px; border-radius:8px; display:flex; gap:10px; align-items:center; border:1px solid var(--bd); }
.m-icon { width:40px; height:40px; border-radius:6px; }
.ovl { position:absolute; inset:0; background:rgba(0,0,0,0.8); display:none; justify-content:center; align-items:center; z-index:99; }
.box { background:var(--sb); padding:30px; border-radius:12px; width:300px; text-align:center; }
.trk { height:6px; background:var(--bd); border-radius:3px; margin:15px 0; overflow:hidden; } #bar { height:100%; width:0; background:var(--acc); transition:width 0.2s; }
.sw-row { display:flex; justify-content:space-between; margin-bottom:10px; align-items:center; } .tg { accent-color:var(--acc); width:18px; height:18px; } .danger-zone { border-left:3px solid var(--rd); }
.flex-row { display:flex; gap:10px; }
/* LOGIN SCREEN */
.login-overlay { position:fixed; inset:0; background:var(--bg); z-index:1000; display:flex; justify-content:center; align-items:center; }
.login-box { background:var(--sb); padding:40px; border-radius:16px; border:1px solid var(--bd); width:350px; text-align:center; }
.brand-lg { font-size:2rem; font-weight:800; margin-bottom:20px; display:flex; align-items:center; justify-content:center; gap:10px; }
.ico-lg { color:var(--acc); }
EOF

# 4. JS (GAME LOGIC RESTORED + LOGIN)
cat <<EOF > /opt/aetherpanel/public/app.js
const socket=io(); const l=document.getElementById('logs'); let pwd='';

// LOGIN & INIT
function init(){
    fetch('/api/labs/info').then(r=>r.json()).then(d=>{
        if(d.password && d.password !== '') {
            // Show login
        } else {
            document.getElementById('login-screen').style.display = 'none';
            document.getElementById('app-ui').style.filter = 'none';
            document.getElementById('app-ui').style.pointerEvents = 'all';
        }
    });
}
function tryLogin(){
    const p = document.getElementById('login-pass').value;
    fetch('/api/login', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})})
    .then(r=>r.json()).then(d=>{
        if(d.success) {
            pwd = p;
            document.getElementById('login-screen').style.display = 'none';
            document.getElementById('app-ui').style.filter = 'none';
            document.getElementById('app-ui').style.pointerEvents = 'all';
        } else alert('Error');
    });
}
init();

function initT(){const s=localStorage.getItem('theme');if(s==='light')document.body.classList.add('light');}
function togTheme(){document.body.classList.toggle('light');localStorage.setItem('theme',document.body.classList.contains('light')?'light':'dark');}
initT();
function getH(){return pwd?{'Content-Type':'application/json','x-auth':pwd}:{'Content-Type':'application/json'};}
socket.on('console_line',t=>{const d=document.createElement('div');d.innerText=t;l.appendChild(d);l.scrollTop=l.scrollHeight;});
socket.on('status_change',s=>{document.getElementById('bdg').innerText=s;document.getElementById('bdg').className='bdg '+(s==='ONLINE'?'on':'off');});
socket.on('install_progress',p=>{
    const o=document.getElementById('ovl');const f=document.getElementById('bar');const t=document.getElementById('pct');
    if(p==='installing'){t.innerText='Instalando...';f.style.width='100%';}else{o.style.display='flex';f.style.width=p+'%';t.innerText=p+'%';}
    if(p>=100 && p!=='installing') setTimeout(()=>{o.style.display='none'},2000);
});
function nav(v){
    document.querySelectorAll('.view').forEach(e=>e.classList.remove('active'));
    document.querySelectorAll('.n-btn').forEach(e=>e.classList.remove('active'));
    document.getElementById('v-'+v).classList.add('active'); event.currentTarget.classList.add('active');
    document.getElementById('pg-t').innerText=event.currentTarget.innerText.trim();
    if(v==='hardware') loadH(); if(v==='labs') loadL(); if(v==='game') loadG(); if(v==='files') loadFiles();
}
function pwr(a){fetch('/api/power/'+a,{method:'POST',headers:getH()});}
document.getElementById('cmd').addEventListener('keypress',e=>{if(e.key==='Enter'){socket.emit('command',e.target.value);e.target.value='';}});

async function searchM(){
    const q=document.getElementById('m-q').value; if(!q)return;
    const r=await fetch('/api/market/search?q='+q+'&loader=paper'); const d=await r.json();
    const c=document.getElementById('m-res'); c.innerHTML='';
    d.forEach(m=>{c.innerHTML+=\`<div class="m-item"><img src="\${m.icon}" class="m-icon"><div><b>\${m.title}</b><br><button class="btn sm sc" onclick="instM('\${m.id}','\${m.title}.jar')">Instalar</button></div></div>\`;});
}
function instM(id, name){if(!confirm('Instalar?'))return;fetch('/api/market/install',{method:'POST',headers:getH(),body:JSON.stringify({url:id,filename:name})}).then(()=>alert('Instalado'));}
function resetDim(d){if(confirm('¿RESET '+d+'?'))fetch('/api/worlds/reset',{method:'POST',headers:getH(),body:JSON.stringify({dim:d})}).then(()=>alert('Reset OK'));}
async function getV(){const t=document.getElementById('ldr').value;const s=document.getElementById('ver');s.innerHTML='...';s.disabled=true;try{const r=await fetch('/api/versions/'+t);const l=await r.json();s.innerHTML='';l.forEach(v=>s.innerHTML+=\`<option value="\${v}">\${v}</option>\`);s.disabled=false;}catch{}}
async function inst(){const t=document.getElementById('ldr').value;const v=document.getElementById('ver').value;if(confirm('Instalar?'))fetch('/api/install',{method:'POST',headers:getH(),body:JSON.stringify({url:'',type:t,ver:v})});}
document.getElementById('f-inp').onchange=e=>{const f=e.target.files[0];const fd=new FormData();fd.append('file',f);fetch('/api/upload',{method:'POST',headers:{'x-auth':pwd},body:fd}).then(()=>alert('Subido')); loadFiles();};
function loadFiles(){fetch('/api/files/list').then(r=>r.json()).then(d=>{const c=document.getElementById('f-list');c.innerHTML='';d.forEach(f=>{c.innerHTML+=\`<div>\${f.name} (\${f.size})</div>\`})});}

// FULL GAME SETTINGS RESTORED
function loadG(){fetch('/api/config').then(r=>r.json()).then(d=>{
    const p=d.properties;
    document.getElementById('g-motd').value=p.motd||'';
    document.getElementById('g-max').value=p['max-players']||20;
    document.getElementById('g-port').value=p['server-port']||25565;
    document.getElementById('g-level').value=p['level-name']||'world';
    document.getElementById('g-seed').value=p['level-seed']||'';
    document.getElementById('g-view').value=p['view-distance']||10;
    document.getElementById('g-diff').value=p['difficulty']||'normal';
    document.getElementById('g-crack').checked=(p['online-mode']==='false');
    document.getElementById('g-pvp').checked=(p['pvp']!=='false');
    document.getElementById('g-hc').checked=(p['hardcore']==='true');
    document.getElementById('g-fly').checked=(p['allow-flight']==='true');
    document.getElementById('g-cmd').checked=(p['enable-command-block']==='true');
    document.getElementById('g-monsters').checked=(p['spawn-monsters']!=='false');
    document.getElementById('g-npcs').checked=(p['spawn-npcs']!=='false');
    document.getElementById('g-nether').checked=(p['allow-nether']!=='false');
    document.getElementById('g-white').checked=(p['white-list']==='true');
});}

function saveG(){
    const p={
        'motd':document.getElementById('g-motd').value, 'max-players':document.getElementById('g-max').value, 'server-port':document.getElementById('g-port').value,
        'level-name':document.getElementById('g-level').value, 'level-seed':document.getElementById('g-seed').value, 'view-distance':document.getElementById('g-view').value,
        'difficulty':document.getElementById('g-diff').value,
        'online-mode':document.getElementById('g-crack').checked?'false':'true', 'pvp':document.getElementById('g-pvp').checked?'true':'false',
        'hardcore':document.getElementById('g-hc').checked?'true':'false', 'allow-flight':document.getElementById('g-fly').checked?'true':'false',
        'enable-command-block':document.getElementById('g-cmd').checked?'true':'false', 'spawn-monsters':document.getElementById('g-monsters').checked?'true':'false',
        'spawn-npcs':document.getElementById('g-npcs').checked?'true':'false', 'allow-nether':document.getElementById('g-nether').checked?'true':'false',
        'white-list':document.getElementById('g-white').checked?'true':'false'
    };
    fetch('/api/game-settings',{method:'POST',headers:getH(),body:JSON.stringify(p)}).then(()=>alert('Guardado'));
}

function loadH(){fetch('/api/config').then(r=>r.json()).then(d=>{document.getElementById('h-aikar').checked=d.settings.aikar;document.getElementById('h-ram').value=parseInt(d.settings.ram)||4;});}
function saveH(){const r=document.getElementById('h-ram').value+'G';const a=document.getElementById('h-aikar').checked;fetch('/api/config',{method:'POST',headers:getH(),body:JSON.stringify({settings:{ram:r,aikar:a}})}).then(()=>alert('Guardado'));}
function loadL(){fetch('/api/labs/info').then(r=>r.json()).then(d=>{pwd=d.password||'';document.getElementById('l-pass').value=pwd;});}
function saveA(){pwd=document.getElementById('l-pass').value;fetch('/api/labs/set-auth',{method:'POST',headers:getH(),body:JSON.stringify({password:pwd})}).then(()=>alert('OK'));}
function wipe(){if(confirm('WIPE?'))fetch('/api/labs/wipe',{method:'POST',headers:getH()});}
function chkUp(){fetch('/api/update/check').then(r=>r.json()).then(d=>{if(d.needsUpdate&&confirm('Update?'))fetch('/api/update/pull',{method:'POST',headers:getH()});else alert('Up to date');});}
EOF

cd /opt/aetherpanel
npm install
systemctl restart aetherpanel

IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}>>> NEBULA v4.1 RESTAURADA.${NC}"
echo -e "URL: http://${IP}:3000"