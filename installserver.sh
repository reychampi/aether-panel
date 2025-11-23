#!/bin/bash

# ============================================================
# AETHER NEBULA v1.0 - GOLD EDITION
# Stable Core + AutoUpdate Fixed + Polished UI
# ============================================================

set -e
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
VIOLET='\033[0;35m'
GREEN='\033[0;32m'
NC='\033[0m'

clear
echo -e "${MAGENTA}=================================================${NC}"
echo -e "${VIOLET}   ✨ NEBULA v1.0 (GOLD EDITION) INSTALANDO...   ${NC}"
echo -e "${MAGENTA}=================================================${NC}"

# 1. ENTORNO Y GIT
echo -e "${CYAN}[1/8] Preparando sistema base...${NC}"
apt-get update -y > /dev/null
apt-get install -y git nodejs npm curl unzip zip tar build-essential ufw openjdk-21-jre-headless openjdk-17-jre-headless openjdk-8-jre-headless > /dev/null || true

# 2. ESTRUCTURA DE DIRECTORIOS
echo -e "${CYAN}[2/8] Creando arquitectura de archivos...${NC}"
mkdir -p /opt/aetherpanel
mkdir -p /opt/aetherpanel/public
mkdir -p /opt/aetherpanel/servers/default
mkdir -p /opt/aetherpanel/uploads
mkdir -p /opt/aetherpanel/modules
mkdir -p /opt/aetherpanel/backups

# 3. CONFIGURACIÓN GIT (AUTO-UPDATE FIX)
echo -e "${CYAN}[3/8] Inicializando Repositorio Git (Auto-Update)...${NC}"
cd /opt/aetherpanel
git config --global --add safe.directory /opt/aetherpanel
if [ ! -d ".git" ]; then
    git init
    git remote add origin https://github.com/reychampi/nebula.git
    git branch -M main
    # Hacemos un fetch inicial silencioso para conectar con el remoto
    git fetch origin main || echo "Nota: Repositorio remoto no accesible aún (normal si está vacío)."
else
    git remote set-url origin https://github.com/reychampi/nebula.git
fi

# 4. DEPENDENCIAS
echo -e "${CYAN}[4/8] Instalando librerías del núcleo...${NC}"
cat <<EOF > /opt/aetherpanel/package.json
{
  "name": "nebula-gold",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "cors": "^2.8.5",
    "multer": "^1.4.5-lts.1",
    "archiver": "^6.0.1",
    "systeminformation": "^5.21.0",
    "axios": "^1.6.2",
    "node-schedule": "^2.1.1",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0"
  }
}
EOF

# 5. MÓDULOS DEL BACKEND (AQUÍ ESTÁ EL ARREGLO)
echo -e "${CYAN}[5/8] Compilando módulos (Update, Market, Worlds)...${NC}"

# --- UPDATER MODULE (FIXED) ---
cat <<EOF > /opt/aetherpanel/modules/updater.js
const { exec } = require('child_process');
const path = require('path');

class Updater {
    constructor() { this.cwd = path.join(__dirname, '..'); }

    check() {
        return new Promise((resolve) => {
            exec('git fetch origin', { cwd: this.cwd }, (err) => {
                if (err) return resolve({ needsUpdate: false, error: 'No git repo' });
                exec('git status -uno', { cwd: this.cwd }, (err, stdout) => {
                    const output = stdout.toString();
                    const needsUpdate = output.includes('behind');
                    resolve({ needsUpdate, msg: needsUpdate ? 'Nueva versión disponible.' : 'Sistema actualizado.' });
                });
            });
        });
    }

    pull() {
        return new Promise((resolve, reject) => {
            const cmd = 'git reset --hard HEAD && git pull origin main && npm install';
            exec(cmd, { cwd: this.cwd }, (err, stdout) => {
                if (err) reject(err); else resolve(stdout);
            });
        });
    }
}
module.exports = Updater;
EOF

# --- MARKETPLACE MODULE ---
cat <<EOF > /opt/aetherpanel/modules/marketplace.js
const axios = require('axios');
const fs = require('fs');
const path = require('path');

class Market {
    constructor(basePath) { this.basePath = basePath; }
    async search(query, loader='paper') {
        let facet = '["categories:bukkit"]';
        if(loader==='fabric') facet = '["categories:fabric"]';
        if(loader==='forge'||loader==='neoforge') facet = '["categories:forge"]';
        try {
            const url = \`https://api.modrinth.com/v2/search?query=\${query}&facets=[\${facet}]&limit=12\`;
            const r = await axios.get(url);
            return r.data.hits.map(h => ({ title: h.title, icon: h.icon_url, author: h.author, id: h.project_id }));
        } catch(e) { return []; }
    }
    async install(projectId, filename) {
        const v = await axios.get(\`https://api.modrinth.com/v2/project/\${projectId}/version\`);
        const fileObj = v.data[0].files[0];
        let subDir = 'mods';
        if(fs.existsSync(path.join(this.basePath, 'plugins'))) subDir = 'plugins';
        const targetDir = path.join(this.basePath, subDir);
        if(!fs.existsSync(targetDir)) fs.mkdirSync(targetDir);
        
        const writer = fs.createWriteStream(path.join(targetDir, filename));
        const response = await axios({ url: fileObj.url, method: 'GET', responseType: 'stream' });
        response.data.pipe(writer);
        return new Promise((res, rej) => { writer.on('finish', res); writer.on('error', rej); });
    }
}
module.exports = Market;
EOF

# --- WORLDS MODULE ---
cat <<EOF > /opt/aetherpanel/modules/worlds.js
const fs = require('fs');
const path = require('path');
class Worlds {
    constructor(basePath) { this.basePath = basePath; }
    resetDimension(dim) {
        let targets = [];
        if(dim === 'nether') targets = ['world/DIM-1', 'world_nether']; 
        if(dim === 'end') targets = ['world/DIM1', 'world_the_end'];
        
        let found = false;
        targets.forEach(t => {
            const p = path.join(this.basePath, t);
            if(fs.existsSync(p)) { fs.rmSync(p, { recursive: true, force: true }); found = true; }
        });
        if(!found) throw new Error('Dimensión no encontrada (aún no generada).');
    }
}
module.exports = Worlds;
EOF

# 6. CORE SERVER & MANAGER
echo -e "${CYAN}[6/8] Escribiendo núcleo del servidor...${NC}"

cat <<EOF > /opt/aetherpanel/server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const multer = require('multer');
const helmet = require('helmet');
const MCManager = require('./mc_manager');
const Market = require('./modules/marketplace');
const Updater = require('./modules/updater');
const Worlds = require('./modules/worlds');
const os = require('os');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const mcServer = new MCManager(io);
const market = new Market(mcServer.basePath);
const updater = new Updater();
const worlds = new Worlds(mcServer.basePath);

// Multer Config
const storageFile = multer.diskStorage({ destination: (req,f,cb)=>cb(null, mcServer.basePath), filename: (req,f,cb)=>cb(null, f.originalname) });
const uploadFile = multer({ storage: storageFile });
const storageCss = multer.diskStorage({ destination: (req,f,cb)=>cb(null, path.join(__dirname, 'public')), filename: (req,f,cb)=>cb(null, 'style.css') });
const uploadCss = multer({ storage: storageCss });

// Auth
const auth = (req, res, next) => {
    const cfg = mcServer.getLabsConfig();
    if(cfg.password && cfg.password !== '') {
        if(req.headers['x-auth'] !== cfg.password) return res.status(403).json({error: 'Forbidden'});
    }
    next();
};

// --- ROUTES ---
app.post('/api/login', (req, res) => {
    const cfg = mcServer.getLabsConfig();
    if(!cfg.password || cfg.password === req.body.password) res.json({success:true});
    else res.status(403).json({error: 'Invalid password'});
});

// Core
app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.get('/api/stats', async (req, res) => res.json(await mcServer.getPerformance()));
app.post('/api/power/:action', auth, async (req, res) => { try{if(mcServer[req.params.action])await mcServer[req.params.action](); res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });

// Config & Install
app.get('/api/config', (req, res) => res.json(mcServer.getConfig()));
app.post('/api/config', auth, (req, res) => { mcServer.saveConfig(req.body); res.json({success:true}); });
app.post('/api/game-settings', auth, (req, res) => { mcServer.updateServerProperties(req.body); res.json({success:true}); });
app.post('/api/install', auth, async (req, res) => { try{await mcServer.installJar(req.body); res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });
app.get('/api/versions/:type', async (req, res) => { try{res.json(await mcServer.fetchVersions(req.params.type));}catch(e){res.status(500).json([]);} });

// Modules
app.get('/api/market/search', async (req, res) => res.json(await market.search(req.query.q, req.query.loader)));
app.post('/api/market/install', auth, async (req, res) => { try{await market.install(req.body.url, req.body.filename); res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });
app.post('/api/worlds/reset', auth, (req, res) => { try{worlds.resetDimension(req.body.dim); res.json({success:true});}catch(e){res.status(500).json({error:e.message});} });
app.get('/api/update/check', async (req, res) => res.json(await updater.check()));
app.post('/api/update/pull', auth, async (req, res) => { try{await updater.pull(); res.json({success:true}); setTimeout(()=>process.exit(0),1000);}catch(e){res.status(500).json({error:e.message});} });

// Files & Uploads
app.post('/api/upload', auth, uploadFile.single('file'), (req, res) => res.json({success: true}));
app.post('/api/upload-css', auth, uploadCss.single('file'), (req, res) => res.json({success: true}));
app.get('/api/files/list', (req, res) => res.json(mcServer.listFiles()));
app.post('/api/files/read', auth, (req, res) => res.send(mcServer.readFile(req.body.file)));
app.post('/api/files/save', auth, (req, res) => { mcServer.saveFile(req.body.file, req.body.content); res.json({success:true}); });

// Players & Labs
app.get('/api/players', (req, res) => res.json(mcServer.players));
app.post('/api/players/action', auth, (req, res) => { mcServer.playerAction(req.body.action, req.body.player); res.json({success:true}); });
app.get('/api/labs/info', (req, res) => res.json(mcServer.getLabsConfig()));
app.post('/api/labs/set-auth', (req, res) => { mcServer.setLabsAuth(req.body.password); res.json({success:true}); });
app.post('/api/labs/set-discord', auth, (req, res) => { mcServer.setDiscord(req.body.url); res.json({success:true}); });
app.post('/api/labs/wipe', auth, async (req, res) => { await mcServer.labsWipe(); res.json({success:true}); });
app.post('/api/labs/backup', auth, async (req, res) => { await mcServer.createBackup(); res.json({success:true}); });
app.post('/api/labs/fix-eula', auth, (req, res) => { mcServer.fixEula(); res.json({success:true}); });

io.on('connection', (s) => {
    s.emit('logs', mcServer.getRecentLogs());
    s.on('command', (c) => mcServer.sendCommand(c));
});

server.listen(3000, () => console.log('Nebula v1.0 Gold Online'));
EOF

cat <<EOF > /opt/aetherpanel/mc_manager.js
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const archiver = require('archiver');
const si = require('systeminformation');

class MCManager {
    constructor(io) {
        this.io = io;
        this.basePath = path.join(__dirname, 'servers', 'default');
        this.settingsPath = path.join(__dirname, 'servers', 'aether.json');
        this.backupPath = path.join(__dirname, 'backups');
        if (!fs.existsSync(this.basePath)) fs.mkdirSync(this.basePath, { recursive: true });
        if (!fs.existsSync(this.backupPath)) fs.mkdirSync(this.backupPath, { recursive: true });
        this.settings = this.loadSettings();
        this.status = 'OFFLINE';
        this.logs = [];
        this.players = [];
        setInterval(() => this.checkCrash(), 5000);
        setInterval(() => this.updatePlayerList(), 10000);
    }
    loadSettings() {
        if (fs.existsSync(this.settingsPath)) return JSON.parse(fs.readFileSync(this.settingsPath, 'utf8'));
        return { ram: '4G', javaVersion: '21', labs: { password: '', discord: '' } }; 
    }
    saveConfig(data) { if(data.settings) { this.settings = { ...this.settings, ...data.settings }; this.persist(); } }
    persist() { fs.writeFileSync(this.settingsPath, JSON.stringify(this.settings, null, 2)); }
    getLabsConfig() { return this.settings.labs || {}; }
    setLabsAuth(pwd) { this.settings.labs.password = pwd; this.persist(); }
    setDiscord(url) { this.settings.labs.discord = url; this.persist(); }
    async sendDiscord(msg, color=0x7289DA) {
        const url = this.settings.labs?.discord;
        if(!url) return;
        try { await axios.post(url, { embeds: [{ title: 'Nebula Server', description: msg, color: color }] }); } catch(e) {}
    }
    checkCrash() {
        if(this.status === 'ONLINE' && !this.process) {
            this.log('⚠ Crash detected. Restarting...'); this.sendDiscord('⚠ Server Crashed. Restarting.', 0xFF0000); this.start();
        }
    }
    async start() {
        if (this.status !== 'OFFLINE') return;
        this.fixEula();
        let jar = this.findJar();
        if(!jar) { this.log('❌ No JAR found.'); return; }
        this.status = 'STARTING'; this.io.emit('status_change', this.status);
        this.sendDiscord('🟢 Starting...', 0x00FF00);
        let cmd = this.getJavaCmd();
        const ram = this.settings.ram || '4G';
        const args = ['-Xms'+ram, '-Xmx'+ram, '-DPaper.IgnoreJavaVersion=true'];
        if (parseInt(this.settings.javaVersion) >= 17) args.push('--add-modules=jdk.incubator.vector');
        args.push('-jar', jar, 'nogui');
        this.process = spawn(cmd, args, { cwd: this.basePath });
        this.process.stdout.on('data', d => {
            const s = d.toString(); this.log(s);
            if(s.includes('players online:')) {
                const parts = s.split(':'); if(parts.length > 1) { const names = parts[parts.length-1].trim().split(', '); this.players = names[0]!==''?names:[]; }
            }
            if(s.includes('Done')) { this.status='ONLINE'; this.io.emit('status_change',this.status); this.sendDiscord('✅ Online'); }
        });
        this.process.stderr.on('data', d => this.log('LOG: '+d));
        this.process.on('close', c => { this.status='OFFLINE'; this.process=null; this.io.emit('status_change',this.status); this.sendDiscord('🔴 Offline'); this.players=[]; });
    }
    async stop() { if(this.process) { this.status='STOPPING'; this.io.emit('status_change',this.status); this.process.stdin.write('stop\n'); } }
    async restart() { await this.stop(); setTimeout(() => this.start(), 5000); }
    sendCommand(c) { if(this.process) this.process.stdin.write(c+'\n'); }
    getJavaCmd() {
        const v = this.settings.javaVersion;
        if(v==='8') return '/usr/lib/jvm/java-8-openjdk-amd64/bin/java';
        if(v==='17') return '/usr/lib/jvm/java-17-openjdk-amd64/bin/java';
        return '/usr/lib/jvm/java-21-openjdk-amd64/bin/java';
    }
    findJar() {
        const files = fs.readdirSync(this.basePath);
        if(files.includes('fabric-server-launch.jar')) return 'fabric-server-launch.jar';
        if(files.includes('server.jar')) return 'server.jar';
        return files.find(f => (f.includes('forge')||f.includes('neoforge')) && f.endsWith('.jar') && !f.includes('installer'));
    }
    fixEula() { fs.writeFileSync(path.join(this.basePath, 'eula.txt'), 'eula=true'); }
    getConfig() { return { properties: this.readPropertiesRaw(), settings: this.settings }; }
    readPropertiesRaw() { try{return fs.readFileSync(path.join(this.basePath,'server.properties'),'utf8').split('\n').reduce((a,l)=>{if(l.includes('=')&&!l.startsWith('#')){const[k,v]=l.split('=');a[k.trim()]=v?v.trim():'';}return a;},{});}catch{return{}}}
    updateServerProperties(n) { const c=this.readPropertiesRaw(); for(const[k,v] of Object.entries(n))c[k]=v; fs.writeFileSync(path.join(this.basePath,'server.properties'), '#Gen\n'+Object.entries(c).map(([k,v])=>\`\${k}=\${v}\`).join('\n')); }
    async installJar(data) {
        const { url, type } = data; if (!url) throw new Error('URL error');
        this.log('🌐 Downloading ' + type);
        let dest = 'server.jar'; if(type.includes('forge')) dest = 'installer.jar'; if(type==='fabric') dest = 'server.jar';
        return new Promise((res, rej) => {
            const curl = spawn('curl', ['-L','-k','-f','-o', dest, url], { cwd: this.basePath });
            curl.stderr.on('data', d => { const m = d.toString().match(/(\d+)(\.\d+)?%/); if(m) this.io.emit('install_progress', Math.floor(parseFloat(m[0]))); });
            curl.on('close', async c => { if(c===0) { this.io.emit('install_progress', 100); if(type.includes('forge')) await this.runInstaller(); res(); } else rej(new Error('Curl error')); });
        });
    }
    async runInstaller() {
        this.log('⚙️ Installing Forge...'); this.io.emit('install_progress', 'installing');
        return new Promise((res, rej) => {
            const p = spawn('java', ['-jar', 'installer.jar', '--installServer'], { cwd: this.basePath });
            p.stdout.on('data', d => this.log('Install: '+d));
            p.on('close', c => { if(c===0) { try{fs.unlinkSync(path.join(this.basePath,'installer.jar'))}catch(e){} res(); } else rej(new Error('Install failed')); });
        });
    }
    async fetchVersions(type) {
        if(type==='paper') return (await axios.get('https://api.papermc.io/v2/projects/paper')).data.versions.reverse();
        if(type==='vanilla') return (await axios.get('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json')).data.versions.filter(v=>v.type==='release').map(v=>v.id);
        if(type==='forge') return Object.keys((await axios.get('https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json')).data.promos).map(k=>k.split('-')[0]).filter((v,i,a)=>a.indexOf(v)===i).sort().reverse();
        if(type==='neoforge') {
            const r = await axios.get('https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml');
            return r.data.match(/<version>(.*?)<\/version>/g).map(v => v.replace(/<\/?version>/g, '')).reverse();
        }
        return [];
    }
    async createBackup() {
        this.log('📦 Backup...'); const name = \`backup-\${Date.now()}.zip\`;
        const out = fs.createWriteStream(path.join(this.backupPath, name)); const arc = archiver('zip', { zlib: { level: 9 } });
        return new Promise((res)=>{ out.on('close', () => { this.log('✅ Backup saved: '+name); res(); }); arc.pipe(out); arc.glob('**/*', { cwd: this.basePath, ignore: ['*.jar', 'logs/*'] }); arc.finalize(); });
    }
    async labsWipe() {
        if(this.status !== 'OFFLINE') throw new Error('Stop first');
        await this.createBackup(); const files = fs.readdirSync(this.basePath);
        for(const f of files) { if(f!=='aether.json') fs.rmSync(path.join(this.basePath, f), {recursive:true, force:true}); }
        this.log('✅ Wiped.');
    }
    async getPerformance() { const mem=await si.mem(); const cpu=await si.currentLoad(); return { ram_used:(mem.active/1e9).toFixed(2), ram_total:(mem.total/1e9).toFixed(2), cpu:cpu.currentLoad.toFixed(1) }; }
    listFiles() { return fs.readdirSync(this.basePath).map(f => ({name:f, type:fs.statSync(path.join(this.basePath,f)).isDirectory()?'dir':'file'})).sort((a,b)=>(a.type==='dir'?-1:1)); }
    readFile(f) { if(f.includes('..'))return''; return fs.readFileSync(path.join(this.basePath,f),'utf8'); }
    saveFile(f,c) { if(!f.includes('..')) fs.writeFileSync(path.join(this.basePath,f),c); }
    log(msg) { this.logs.push(msg); if(this.logs.length>600)this.logs.shift(); this.io.emit('console_line', msg); }
}
module.exports = MCManager;
EOF

# 7. FRONTEND (HOMOGÉNEO + PROFESIONAL)
echo -e "${CYAN}[7/8] Desplegando interfaz v1.0 Nebula Gold...${NC}"

cat <<EOF > /opt/aetherpanel/public/index.html
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Nebula v1.0</title>
    <link rel="stylesheet" href="style.css">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono&display=swap" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/remixicon@3.5.0/fonts/remixicon.css" rel="stylesheet">
    <script src="/socket.io/socket.io.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ace/1.32.6/ace.js"></script>
</head>
<body>
    <div id="login-screen" class="login-overlay">
        <div class="login-card">
            <div class="login-logo"><i class="ri-shining-2-fill"></i> NEBULA</div>
            <input type="password" id="login-pass" placeholder="Contraseña de acceso..." onkeypress="if(event.key==='Enter') tryLogin()">
            <button class="btn btn-primary full" onclick="tryLogin()">Acceder</button>
        </div>
    </div>

    <div class="app" id="app-ui">
        <aside class="sidebar">
            <div class="brand"><i class="ri-shining-2-fill brand-ico"></i> NEBULA <span class="tag">1.0</span></div>
            <nav>
                <div class="nav-group">SERVIDOR</div>
                <button onclick="nav('console')" class="nav-btn active"><i class="ri-terminal-box-fill"></i> Consola</button>
                <button onclick="nav('stats')" class="nav-btn"><i class="ri-bar-chart-fill"></i> Rendimiento</button>
                <div class="nav-group">GESTIÓN</div>
                <button onclick="nav('files')" class="nav-btn"><i class="ri-folder-5-fill"></i> Archivos</button>
                <button onclick="nav('market')" class="nav-btn"><i class="ri-store-2-fill"></i> Mercado</button>
                <button onclick="nav('install')" class="nav-btn"><i class="ri-download-cloud-2-fill"></i> Versiones</button>
                <div class="nav-group">CONFIGURACIÓN</div>
                <button onclick="nav('game')" class="nav-btn"><i class="ri-settings-4-fill"></i> Juego</button>
                <button onclick="nav('hardware')" class="nav-btn"><i class="ri-cpu-line"></i> Hardware</button>
                <button onclick="nav('labs')" class="nav-btn labs-text"><i class="ri-flask-fill"></i> Labs</button>
            </nav>
            <div class="sidebar-footer">
                <button class="theme-toggle" onclick="cycleTheme()"><i class="ri-computer-line" id="theme-ico"></i></button>
                <div id="status-bdg" class="status off">OFFLINE</div>
            </div>
        </aside>

        <main>
            <header>
                <h2 id="view-title">Consola</h2>
                <div class="actions">
                    <button class="btn btn-go" onclick="pwr('start')"><i class="ri-play-fill"></i> Iniciar</button>
                    <button class="btn btn-wa" onclick="pwr('restart')"><i class="ri-refresh-line"></i> Reiniciar</button>
                    <button class="btn btn-st" onclick="pwr('stop')"><i class="ri-stop-fill"></i> Detener</button>
                </div>
            </header>

            <div id="v-console" class="view active">
                <div id="dl-ovl" class="overlay"><div class="modal"><h3>Procesando...</h3><div class="progress-bar"><div id="prog-fill"></div></div><span id="prog-txt">0%</span></div></div>
                <div class="console-wrap"><div id="logs"></div><div class="input-wrap"><i class="ri-arrow-right-s-line"></i><input id="cmd" placeholder="Enviar comando..." autocomplete="off"></div></div>
            </div>

            <div id="v-stats" class="view"><div class="grid-2"><div class="card"><h3>RAM</h3><div class="chart-con"><canvas id="ramChart"></canvas></div></div><div class="card"><h3>CPU</h3><div class="chart-con"><canvas id="cpuChart"></canvas></div></div></div></div>

            <div id="v-market" class="view">
                <div class="card">
                    <h3>Marketplace (Modrinth)</h3>
                    <div class="flex-row"><input id="m-q" placeholder="Buscar plugins/mods..."><button class="btn btn-primary" onclick="searchM()">Buscar</button></div>
                    <div id="m-res" class="market-grid"></div>
                </div>
            </div>

            <div id="v-game" class="view">
                <div class="grid-2">
                    <div class="card">
                        <h3>General</h3>
                        <label>MOTD</label><input id="g-motd">
                        <label>Máx. Jugadores</label><input type="number" id="g-max">
                    </div>
                    <div class="card">
                        <h3>Reglas</h3>
                        <div class="switch-row"><span>Crackeado</span><input type="checkbox" id="g-crack" class="toggle"></div>
                        <div class="switch-row"><span>PVP</span><input type="checkbox" id="g-pvp" class="toggle"></div>
                        <div class="switch-row"><span>Hardcore</span><input type="checkbox" id="g-hc" class="toggle"></div>
                    </div>
                </div>
                <button class="btn btn-primary full" onclick="saveG()">Guardar Configuración</button>
            </div>

            <div id="v-files" class="view">
                <div class="card">
                    <div class="flex-head"><h3>Archivos</h3><button class="btn btn-secondary sm" onclick="document.getElementById('f-inp').click()">Subir</button><input type="file" id="f-inp" hidden></div>
                    <div id="f-list" class="file-list"></div>
                </div>
                <div id="editor-box" style="display:none" class="card full-h">
                    <div class="flex-head"><h3>Editando: <span id="ed-name"></span></h3><div class="acts"><button class="btn btn-primary sm" onclick="saveFile()">Guardar</button><button class="btn btn-secondary sm" onclick="closeEd()">Cerrar</button></div></div>
                    <div id="ace-editor"></div>
                </div>
            </div>

            <div id="v-install" class="view">
                <div class="card">
                    <h3>Instalador</h3>
                    <div class="grid-2">
                        <div><label>Software</label><select id="ldr" onchange="getV()"><option value="paper">PaperMC</option><option value="vanilla">Vanilla</option><option value="forge">Forge</option><option value="neoforge">NeoForge</option><option value="fabric">Fabric</option></select></div>
                        <div><label>Versión</label><select id="ver" disabled><option>...</option></select></div>
                    </div>
                    <button class="btn btn-primary full" onclick="inst()">Instalar</button>
                </div>
            </div>

            <div id="v-labs" class="view">
                <div class="grid-2">
                    <div class="card">
                        <h3>Actualizaciones</h3>
                        <div class="flex-row" style="justify-content:space-between"><span>Estado: <span id="upd-st">Desconocido</span></span><button class="btn btn-secondary" onclick="chkUp()">Buscar Update</button></div>
                    </div>
                    <div class="card"><h3>Seguridad</h3><div class="flex-row"><input type="password" id="l-pass" placeholder="Nueva clave"><button class="btn btn-primary" onclick="saveAuth()">Guardar</button></div></div>
                    <div class="card danger"><h3>Zona Peligrosa</h3><div class="flex-row"><button class="btn btn-st full" onclick="wipe()">WIPE SERVER</button><button class="btn btn-wa full" onclick="backup()">BACKUP</button></div></div>
                    <div class="card">
                        <h3>Personalizar CSS</h3>
                        <button class="btn btn-secondary full" onclick="document.getElementById('css-inp').click()">Subir style.css propio</button>
                        <input type="file" id="css-inp" hidden onchange="uploadCSS()">
                    </div>
                </div>
            </div>

            <div id="v-hardware" class="view">
                <div class="card">
                    <h3>Java & RAM</h3>
                    <div class="radios">
                        <label class="r-box"><input type="radio" name="j" value="21"> 21</label>
                        <label class="r-box"><input type="radio" name="j" value="17"> 17</label>
                        <label class="r-box"><input type="radio" name="j" value="8"> 8</label>
                    </div>
                    <h3>Asignación: <span id="rv">4G</span></h3>
                    <input type="range" id="rs" min="1" max="16" oninput="document.getElementById('rv').innerText=this.value+'G'">
                    <button class="btn btn-primary full" onclick="saveH()">Aplicar</button>
                </div>
            </div>
        </main>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

cat <<EOF > /opt/aetherpanel/public/style.css
:root {
    --bg: #09090b; --sb: #121215; --cd: #18181b; --bd: #27272a; --tx: #e4e4e7; --dm: #a1a1aa;
    --ac: #6366f1; --ac-h: #4f46e5; --gr: #10b981; --rd: #ef4444; --yl: #f59e0b;
    --in-bg: #202023;
}
body.light {
    --bg: #f8fafc; --sb: #ffffff; --cd: #ffffff; --bd: #e2e8f0; --tx: #0f172a; --dm: #64748b;
    --ac: #4f46e5; --in-bg: #f1f5f9;
}

* { box-sizing: border-box; transition: background 0.2s, color 0.2s, border 0.2s; }
body { margin: 0; background: var(--bg); color: var(--tx); font-family: 'Inter', sans-serif; height: 100vh; overflow: hidden; }

.app { display: flex; height: 100%; }
.sidebar { width: 260px; background: var(--sb); border-right: 1px solid var(--bd); display: flex; flex-direction: column; padding: 24px; z-index: 10; }
.brand { display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 1.1rem; margin-bottom: 30px; color: var(--tx); }
.brand-ico { color: var(--ac); font-size: 1.4rem; }
.tag { font-size: 0.7rem; background: rgba(99,102,241,0.1); color: var(--ac); padding: 2px 6px; border-radius: 4px; margin-left: 5px; }

.nav-group { font-size: 0.7rem; font-weight: 700; color: var(--dm); margin: 20px 0 8px 0; letter-spacing: 0.5px; }
.nav-btn { width: 100%; text-align: left; padding: 10px 12px; border: none; background: transparent; color: var(--dm); border-radius: 8px; cursor: pointer; font-weight: 500; display: flex; align-items: center; gap: 10px; font-family: inherit; margin-bottom: 2px; }
.nav-btn:hover { background: var(--bd); color: var(--tx); }
.nav-btn.active { background: var(--ac); color: white; font-weight: 600; box-shadow: 0 4px 12px rgba(99,102,241,0.2); }
.labs-text { color: var(--rd); } .labs-text:hover { background: rgba(239,68,68,0.1); }

.sidebar-footer { margin-top: auto; border-top: 1px solid var(--bd); padding-top: 20px; display: flex; justify-content: space-between; align-items: center; }
.theme-toggle { background: transparent; border: 1px solid var(--bd); color: var(--tx); width: 36px; height: 36px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
.status { padding: 6px 12px; border-radius: 6px; font-weight: 800; font-size: 0.75rem; }
.off { background: rgba(239,68,68,0.15); color: var(--rd); } .on { background: rgba(16,185,129,0.15); color: var(--gr); }

main { flex: 1; padding: 32px; display: flex; flex-direction: column; overflow: hidden; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
h2 { margin: 0; font-weight: 700; letter-spacing: -0.5px; }

.btn { padding: 10px 20px; border-radius: 8px; border: none; font-weight: 600; cursor: pointer; color: white; font-family: inherit; transition: 0.2s; display: inline-flex; align-items: center; gap: 8px; font-size: 0.9rem; }
.btn-go { background: var(--gr); } .btn-wa { background: var(--yl); color: #000; } .btn-st { background: var(--rd); }
.btn-primary { background: var(--ac); } .btn-secondary { background: var(--bd); color: var(--tx); }
.full { width: 100%; justify-content: center; margin-top: 15px; } .sm { padding: 6px 12px; font-size: 0.8rem; }

.view { display: none; flex-direction: column; height: 100%; animation: fade 0.2s ease; } .view.active { display: flex; }
@keyframes fade { from{opacity:0;transform:translateY(5px)} to{opacity:1;transform:translateY(0)} }

.card { background: var(--cd); border: 1px solid var(--bd); border-radius: 16px; padding: 24px; margin-bottom: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.02); }
.grid-2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
.console-wrap { flex: 1; background: #0c0c0c; border-radius: 12px; border: 1px solid var(--bd); display: flex; flex-direction: column; overflow: hidden; }
#logs { flex: 1; padding: 16px; overflow-y: auto; font-family: 'JetBrains Mono', monospace; font-size: 0.85rem; color: #d4d4d8; white-space: pre-wrap; }
.input-wrap { border-top: 1px solid #333; padding: 12px; background: #111; display: flex; gap: 10px; align-items: center; }
#cmd { background: transparent; border: none; color: var(--gr); flex: 1; outline: none; font-family: 'JetBrains Mono'; }

label { display: block; font-size: 0.85rem; color: var(--dim); margin-bottom: 6px; font-weight: 500; }
input, select { width: 100%; padding: 10px; background: var(--in-bg); border: 1px solid var(--bd); border-radius: 8px; color: var(--tx); outline: none; margin-bottom: 12px; transition: 0.2s; }
input:focus, select:focus { border-color: var(--ac); box-shadow: 0 0 0 2px rgba(99,102,241,0.1); }

/* Market */
.market-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 12px; margin-top: 15px; max-height: 400px; overflow-y: auto; }
.m-item { background: var(--bg); padding: 12px; border-radius: 8px; display: flex; gap: 12px; align-items: center; border: 1px solid var(--bd); }
.m-icon { width: 40px; height: 40px; border-radius: 6px; }

/* Login */
.login-overlay { position: fixed; inset: 0; background: var(--bg); z-index: 100; display: flex; justify-content: center; align-items: center; }
.login-card { background: var(--cd); padding: 40px; border-radius: 16px; border: 1px solid var(--bd); width: 350px; text-align: center; }
.login-logo { font-size: 1.5rem; font-weight: 800; margin-bottom: 20px; color: var(--tx); }

.overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.8); z-index: 50; display: none; justify-content: center; align-items: center; backdrop-filter: blur(5px); }
.modal { background: var(--cd); padding: 30px; border-radius: 16px; width: 300px; text-align: center; border: 1px solid var(--bd); }
.progress-bar { height: 6px; background: var(--bg); border-radius: 3px; margin: 20px 0; overflow: hidden; }
#prog-fill { height: 100%; width: 0; background: var(--ac); transition: width 0.2s; }

/* Extra */
.switch-row { display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--bd); }
.toggle { accent-color: var(--ac); width: 20px; height: 20px; }
.chart-con { position: relative; height: 200px; }
.flex-row { display: flex; gap: 10px; } .flex-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
.danger { border-left: 4px solid var(--rd); }
.f-row { display: flex; justify-content: space-between; padding: 10px; border-bottom: 1px solid var(--bd); cursor: pointer; }
.f-row:hover { background: var(--bg); }
#ace-editor { width: 100%; height: 500px; border-radius: 8px; border: 1px solid var(--bd); }
EOF

cat <<EOF > /opt/aetherpanel/public/app.js
const socket=io(); const l=document.getElementById('logs');
let pwd='', ramC, cpuC, curF='';

// THEME
const themes=['dark','light','auto']; let tIdx=0;
function initT(){const s=localStorage.getItem('t')||'auto';tIdx=themes.indexOf(s);applyT(s);}
function cycleTheme(){tIdx=(tIdx+1)%3;const t=themes[tIdx];localStorage.setItem('t',t);applyT(t);}
function applyT(m){
    document.body.classList.remove('light');
    const ico=document.getElementById('theme-ico');
    if(m==='light'){document.body.classList.add('light');ico.className='ri-sun-line';}
    if(m==='dark'){ico.className='ri-moon-line';}
    if(m==='auto'){if(window.matchMedia('(prefers-color-scheme:light)').matches)document.body.classList.add('light');ico.className='ri-computer-line';}
    updateCharts(m);
}
initT();

// AUTH
function checkLogin(){
    fetch('/api/labs/info').then(r=>r.json()).then(d=>{
        if(d.password && d.password!==''){
            document.getElementById('login-screen').style.display='flex';
            document.getElementById('app-ui').style.filter='blur(5px)';
        } else {
            document.getElementById('login-screen').style.display='none';
        }
    });
}
function tryLogin(){
    const p=document.getElementById('login-pass').value;
    fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({password:p})})
    .then(r=>r.json()).then(d=>{
        if(d.success){
            pwd=p; document.getElementById('login-screen').style.display='none';
            document.getElementById('app-ui').style.filter='none';
        } else alert('Incorrect');
    });
}
checkLogin();

function getH(){return pwd?{'Content-Type':'application/json','x-auth':pwd}:{'Content-Type':'application/json'};}

// SOCKETS
socket.on('console_line',t=>{const d=document.createElement('div');d.innerText=t;l.appendChild(d);l.scrollTop=l.scrollHeight;});
socket.on('status_change',s=>{const b=document.getElementById('status-bdg');b.innerText=s;b.className='status '+(s==='ONLINE'?'on':'off');});
socket.on('install_progress',p=>{
    const o=document.getElementById('dl-ovl');const f=document.getElementById('prog-fill');const t=document.getElementById('prog-txt');
    if(p==='installing'){t.innerText='Instalando...';f.style.width='100%';}else{o.style.display='flex';f.style.width=p+'%';t.innerText=p+'%';}
    if(p>=100 && p!=='installing') setTimeout(()=>{o.style.display='none'},2000);
});

// NAV
function nav(v){
    document.querySelectorAll('.view').forEach(e=>e.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(e=>e.classList.remove('active'));
    document.getElementById('v-'+v).classList.add('active'); event.currentTarget.classList.add('active');
    document.getElementById('view-title').innerText=event.currentTarget.innerText.trim();
    if(v==='game') loadG(); if(v==='hardware') loadH(); if(v==='labs') loadL(); if(v==='files') loadF();
}
function pwr(a){fetch('/api/power/'+a,{method:'POST',headers:getH()});}
document.getElementById('cmd').addEventListener('keypress',e=>{if(e.key==='Enter'){socket.emit('command',e.target.value);e.target.value='';}});

// MODULES
async function searchM(){
    const q=document.getElementById('m-q').value; if(!q)return;
    const r=await fetch('/api/market/search?q='+q+'&loader=paper'); const d=await r.json();
    const c=document.getElementById('m-res'); c.innerHTML='';
    d.forEach(m=>{c.innerHTML+=\`<div class="m-item"><img src="\${m.icon}" class="m-icon"><div><b>\${m.title}</b><br><button class="btn btn-secondary sm" onclick="instM('\${m.id}','\${m.title}.jar')">Instalar</button></div></div>\`;});
}
function instM(id,n){if(confirm('Instalar?'))fetch('/api/market/install',{method:'POST',headers:getH(),body:JSON.stringify({url:id,filename:n})}).then(()=>alert('OK'));}

async function getV(){const t=document.getElementById('ldr').value;const s=document.getElementById('ver');s.innerHTML='...';s.disabled=true;try{const r=await fetch('/api/versions/'+t);const l=await r.json();s.innerHTML='';l.forEach(v=>s.innerHTML+=\`<option value="\${v}">\${v}</option>\`);s.disabled=false;}catch{}}
async function inst(){const t=document.getElementById('ldr').value;const v=document.getElementById('ver').value;if(confirm('Instalar?'))fetch('/api/install',{method:'POST',headers:getH(),body:JSON.stringify({url:'',type:t,ver:v})});}

// FILES
function loadF(){fetch('/api/files/list').then(r=>r.json()).then(d=>{const c=document.getElementById('f-list');c.innerHTML='';d.forEach(f=>{c.innerHTML+=\`<div class="f-row" onclick="ed('\${f.name}',\${f.type==='dir'})"><span>\${f.name}</span><small>\${f.size}</small></div>\`})});}
let editor; function initEd(){editor=ace.edit("ace-editor");editor.setTheme("ace/theme/twilight");editor.session.setMode("ace/mode/properties");}
function ed(n,d){if(d)return;curF=n;fetch('/api/files/read',{method:'POST',headers:getH(),body:JSON.stringify({file:n})}).then(r=>r.text()).then(c=>{document.getElementById('f-list').parentElement.style.display='none';document.getElementById('editor-box').style.display='block';document.getElementById('ed-name').innerText=n;editor.setValue(c,-1);});}
function saveFile(){fetch('/api/files/save',{method:'POST',headers:getH(),body:JSON.stringify({file:curF,content:editor.getValue()})}).then(()=>alert('Guardado'));}
function closeEd(){document.getElementById('f-list').parentElement.style.display='block';document.getElementById('editor-box').style.display='none';}
document.getElementById('f-inp').onchange=e=>{const fd=new FormData();fd.append('file',e.target.files[0]);fetch('/api/upload',{method:'POST',headers:{'x-auth':pwd},body:fd}).then(()=>alert('Subido'));loadF();};

// CONFIG
function loadG(){fetch('/api/config').then(r=>r.json()).then(d=>{const p=d.properties;document.getElementById('g-motd').value=p.motd||'';document.getElementById('g-max').value=p['max-players']||20;document.getElementById('g-crack').checked=(p['online-mode']==='false');document.getElementById('g-pvp').checked=(p['pvp']!=='false');document.getElementById('g-hc').checked=(p['hardcore']==='true');});}
function saveG(){const p={'motd':document.getElementById('g-motd').value,'max-players':document.getElementById('g-max').value,'online-mode':document.getElementById('g-crack').checked?'false':'true','pvp':document.getElementById('g-pvp').checked?'true':'false','hardcore':document.getElementById('g-hc').checked?'true':'false'};fetch('/api/game-settings',{method:'POST',headers:getH(),body:JSON.stringify(p)}).then(()=>alert('OK'));}
function loadH(){fetch('/api/config').then(r=>r.json()).then(d=>{document.querySelector(\`input[name="j"][value="\${d.settings.javaVersion}"]\`).checked=true;document.getElementById('rs').value=parseInt(d.settings.ram)||4;});}
function saveH(){const j=document.querySelector('input[name="j"]:checked').value;const r=document.getElementById('rs').value+'G';fetch('/api/config',{method:'POST',headers:getH(),body:JSON.stringify({settings:{javaVersion:j,ram:r}})}).then(()=>alert('OK'));}

// LABS
function loadL(){fetch('/api/labs/info').then(r=>r.json()).then(d=>{pwd=d.password||'';document.getElementById('l-pass').value=pwd;document.getElementById('upd-st').innerText=d.updateMsg||'Desconocido';});}
function saveAuth(){pwd=document.getElementById('l-pass').value;fetch('/api/labs/set-auth',{method:'POST',headers:getH(),body:JSON.stringify({password:pwd})}).then(()=>alert('Auth OK'));}
function wipe(){if(confirm('WIPE?'))fetch('/api/labs/wipe',{method:'POST',headers:getH()}).then(()=>alert('Wiped'));}
function chkUp(){fetch('/api/update/check').then(r=>r.json()).then(d=>{if(d.needsUpdate&&confirm('Update?'))fetch('/api/update/pull',{method:'POST',headers:getH()});else alert('Up to date');});}
function uploadCSS(){const fd=new FormData();fd.append('file',document.getElementById('css-inp').files[0]);fetch('/api/upload-css',{method:'POST',headers:{'x-auth':pwd},body:fd}).then(()=>location.reload());}

// CHARTS
function initCharts(){
    const ctxR=document.getElementById('ramChart').getContext('2d');
    const ctxC=document.getElementById('cpuChart').getContext('2d');
    const cfg={type:'line',data:{labels:Array(20).fill(''),datasets:[{data:Array(20).fill(0),borderColor:'#7c3aed',fill:true,backgroundColor:'rgba(124,58,237,0.1)',pointRadius:0}]},options:{responsive:true,maintainAspectRatio:false,scales:{x:{display:false},y:{beginAtZero:true,grid:{color:'#333'}}},plugins:{legend:{display:false}}}};
    ramC=new Chart(ctxR,JSON.parse(JSON.stringify(cfg))); cpuC=new Chart(ctxC,JSON.parse(JSON.stringify(cfg)));
}
function updateCharts(m){const c=m==='light'?'#e5e7eb':'#333';if(ramC){ramC.options.scales.y.grid.color=c;ramC.update();cpuC.options.scales.y.grid.color=c;cpuC.update();}}
function updateStats(){fetch('/api/stats').then(r=>r.json()).then(d=>{ramC.data.datasets[0].data.push((d.ram_used/d.ram_total)*100);ramC.data.datasets[0].data.shift();ramC.update();cpuC.data.datasets[0].data.push(d.cpu);cpuC.data.datasets[0].data.shift();cpuC.update();});}
setInterval(()=>{if(document.getElementById('v-stats').classList.contains('active')) updateStats()},2000);

initCharts(); initEd();
EOF

# 8. FINALIZACIÓN
cd /opt/aetherpanel
npm install
systemctl restart aetherpanel

IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}>>> NEBULA GOLD INSTALADO.${NC}"
echo -e "Panel: http://${IP}:3000"