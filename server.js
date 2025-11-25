const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const MCManager = require('./mc_manager');
const osUtils = require('os-utils');
const os = require('os');
const multer = require('multer');
const axios = require('axios');
const { exec, spawn } = require('child_process');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
const upload = multer({ dest: os.tmpdir() });

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

const mcServer = new MCManager(io);
const SERVER_DIR = path.join(__dirname, 'servers', 'default');
const BACKUP_DIR = path.join(__dirname, 'backups');

// GITHUB CONFIG
const apiClient = axios.create({ headers: { 'User-Agent': 'Nebula-Panel/1.3.0' } });
const REPO_RAW = 'https://raw.githubusercontent.com/reychampi/nebula/main';

// --- INFO API (READ DISK) ---
app.get('/api/info', (req, res) => {
    try {
        const pkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
        res.json({ version: pkg.version });
    } catch (e) { res.json({ version: 'Unknown' }); }
});

// --- LOGICA DE ACTUALIZACIÓN HÍBRIDA ---
app.get('/api/update/check', async (req, res) => {
    try {
        const localPkg = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8'));
        const remotePkg = (await apiClient.get(`${REPO_RAW}/package.json`)).data;
        
        if (remotePkg.version !== localPkg.version) {
            return res.json({ type: 'hard', local: localPkg.version, remote: remotePkg.version });
        }

        const files = ['public/index.html', 'public/style.css', 'public/app.js'];
        let hasChanges = false;
        for (const f of files) {
            const remoteContent = (await apiClient.get(`${REPO_RAW}/${f}`)).data;
            const localPath = path.join(__dirname, f);
            if (fs.existsSync(localPath)) {
                const localContent = fs.readFileSync(localPath, 'utf8');
                if (remoteContent.trim() !== localContent.trim()) {
                    hasChanges = true;
                    break;
                }
            }
        }

        if (hasChanges) return res.json({ type: 'soft', local: localPkg.version, remote: remotePkg.version });
        res.json({ type: 'none' });

    } catch (e) {
        console.error(e);
        res.json({ type: 'error' });
    }
});

app.post('/api/update/perform', async (req, res) => {
    const { type } = req.body;

    if (type === 'hard') {
        io.emit('toast', { type: 'warning', msg: '🔄 Iniciando actualización de sistema...' });
        const updater = spawn('bash', ['/opt/aetherpanel/updater.sh'], { detached: true, stdio: 'ignore' });
        updater.unref();
        res.json({ success: true, mode: 'hard' });
        setTimeout(() => process.exit(0), 1000);
    } 
    else if (type === 'soft') {
        io.emit('toast', { type: 'info', msg: '✨ Actualizando interfaz...' });
        try {
            const files = ['public/index.html', 'public/style.css', 'public/app.js'];
            for (const f of files) {
                const c = (await apiClient.get(`${REPO_RAW}/${f}`)).data;
                fs.writeFileSync(path.join(__dirname, f), c);
            }
            res.json({ success: true, mode: 'soft' });
        } catch (e) { res.status(500).json({ error: e.message }); }
    }
});

// --- PROXY VERSIONES ---
app.post('/api/nebula/versions', async (req, res) => {
    const { type } = req.body;
    try {
        let list = [];
        if (type === 'vanilla') {
            const r = await apiClient.get('https://piston-meta.mojang.com/mc/game/version_manifest_v2.json');
            list = r.data.versions.filter(v => v.type === 'release').map(v => ({ id: v.id, url: v.url, type: 'vanilla' }));
        } else if (type === 'paper') {
            const r = await apiClient.get('https://api.papermc.io/v2/projects/paper');
            list = r.data.versions.reverse().map(v => ({ id: v, type: 'paper' }));
        } else if (type === 'fabric') {
            const r = await apiClient.get('https://meta.fabricmc.net/v2/versions/game');
            list = r.data.filter(v => v.stable).map(v => ({ id: v.version, type: 'fabric' }));
        } else if (type === 'forge') {
            const r = await apiClient.get('https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json');
            const p = r.data.promos;
            const s = new Set();
            Object.keys(p).forEach(k => { const v = k.split('-')[0]; if(v.match(/^\d+\.\d+(\.\d+)?$/)) s.add(v); });
            list = Array.from(s).sort((a, b) => b.localeCompare(a, undefined, { numeric: true, sensitivity: 'base' })).map(v => ({ id: v, type: 'forge' }));
        }
        res.json(list);
    } catch (e) { res.status(500).json({ error: "API Error" }); }
});

app.post('/api/nebula/resolve-vanilla', async (req, res) => {
    try { const r = await apiClient.get(req.body.url); res.json({ url: r.data.downloads.server.url }); } catch (e) { res.status(500).json({error: 'Error resolving'}); }
});

app.get('/api/stats', (req, res) => {
    osUtils.cpuUsage((cpu) => {
        let disk = 0; try { fs.readdirSync(SERVER_DIR).forEach(f => { try { disk += fs.statSync(path.join(SERVER_DIR, f)).size; } catch {} }); } catch {}
        res.json({ cpu: cpu * 100, ram_used: (os.totalmem()-os.freemem())/1048576, ram_total: os.totalmem()/1048576, disk_used: disk/1048576, disk_total: 20480 });
    });
});

app.get('/api/status', (req, res) => res.json(mcServer.getStatus()));
app.post('/api/power/:action', async (req, res) => { try{if(mcServer[req.params.action])await mcServer[req.params.action]();res.json({success:true});}catch(e){res.status(500).json({error:e.message});}});
app.get('/api/config', (req, res) => res.json(mcServer.readProperties()));
app.post('/api/config', (req, res) => { mcServer.writeProperties(req.body); res.json({success:true}); });
app.post('/api/install', async (req, res) => { try{await mcServer.installJar(req.body.url, req.body.filename);res.json({success:true});}catch(e){res.status(500).json({error:e.message});}});
app.get('/api/files', (req, res) => { const t = path.join(SERVER_DIR, (req.query.path||'').replace(/\.\./g, '')); if (!fs.existsSync(t)) return res.json([]); res.json(fs.readdirSync(t, {withFileTypes:true}).map(f => ({ name: f.name, isDir: f.isDirectory(), size: f.isDirectory()?'-':(fs.statSync(path.join(t,f.name)).size/1024).toFixed(1)+' KB'})).sort((a,b)=>a.isDir===b.isDir?0:a.isDir?-1:1)); });
app.post('/api/files/read', (req, res) => { const p = path.join(SERVER_DIR, req.body.file.replace(/\.\./g,'')); if(fs.existsSync(p)) res.json({content:fs.readFileSync(p,'utf8')}); else res.status(404).json({error:'404'}); });
app.post('/api/files/save', (req, res) => { fs.writeFileSync(path.join(SERVER_DIR, req.body.file.replace(/\.\./g,'')), req.body.content); res.json({success:true}); });
app.post('/api/files/upload', upload.single('file'), (req, res) => { if(req.file) { fs.renameSync(req.file.path, path.join(SERVER_DIR, req.file.originalname)); res.json({success:true}); } else res.json({success:false}); });
app.get('/api/backups', (req, res) => { if(!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR); res.json(fs.readdirSync(BACKUP_DIR).filter(f=>f.endsWith('.tar.gz')).map(f=>({name:f, size:(fs.statSync(path.join(BACKUP_DIR,f)).size/1048576).toFixed(2)+' MB'}))); });
app.post('/api/backups/create', (req, res) => { exec(`tar -czf "${path.join(BACKUP_DIR, 'backup-'+Date.now()+'.tar.gz')}" -C "${path.join(__dirname,'servers')}" default`, (e)=>res.json({success:!e})); });
app.post('/api/backups/delete', (req, res) => { fs.unlinkSync(path.join(BACKUP_DIR, req.body.name)); res.json({success:true}); });
app.post('/api/backups/restore', async (req, res) => { await mcServer.stop(); exec(`rm -rf "${SERVER_DIR}"/* && tar -xzf "${path.join(BACKUP_DIR, req.body.name)}" -C "${path.join(__dirname,'servers')}"`, (e)=>res.json({success:!e})); });

// --- MOD INSTALLER API ---
app.post('/api/mods/install', async (req, res) => {
    const { url, name } = req.body;
    const modsDir = path.join(SERVER_DIR, 'mods');
    if (!fs.existsSync(modsDir)) fs.mkdirSync(modsDir);
    io.emit('toast', { type: 'info', msg: `Instalando ${name}...` });
    const fileName = name.replace(/\s+/g, '_') + '.jar';
    const target = path.join(modsDir, fileName);
    const cmd = `wget -q -O "${target}" "${url}"`;
    
    exec(cmd, (error) => {
        if (error) {
            io.emit('toast', { type: 'error', msg: 'Error al descargar mod' });
            res.json({ success: false });
        } else {
            io.emit('toast', { type: 'success', msg: `${name} instalado` });
            res.json({ success: true });
        }
    });
});

io.on('connection', (socket) => {
    socket.emit('logs_history', mcServer.getRecentLogs());
    socket.emit('status_change', mcServer.status);
    socket.on('command', (cmd) => mcServer.sendCommand(cmd));
});

server.listen(3000, () => console.log('Nebula V1.3.0 running'));
