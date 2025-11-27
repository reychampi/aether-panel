const socket = io();
let currentPath = '', currentFile = '', allVersions = [];
let currentStoreMode = 'versions';

// --- 1. INFO & INICIO ---
fetch('/api/info').then(r => r.json()).then(d => {
    document.getElementById('sidebar-version-text').innerText = 'V' + d.version;
    document.getElementById('header-version').innerText = 'V' + d.version;
});

// Cargar IP en Header
fetch('/api/network').then(r => r.json()).then(d => {
    const ipElem = document.getElementById('server-ip-display');
    if(ipElem) {
        ipElem.innerText = `${d.ip}:${d.port}`;
        ipElem.dataset.fullIp = `${d.ip}:${d.port}`;
    }
});
function copyIP() {
    const ip = document.getElementById('server-ip-display').dataset.fullIp;
    navigator.clipboard.writeText(ip).then(() => Toastify({text: '¡IP Copiada!', style:{background:'#10b981'}}).showToast());
}

// --- 2. SHORTCUTS & NAVEGACIÓN ---
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeAllModals();
    // Alt + Número para pestañas
    if (e.altKey && !e.ctrlKey && !e.shiftKey) {
        const map = {'1':'stats','2':'console','3':'files','4':'versions','5':null,'6':'backups','7':'labs','8':'config'};
        if (e.key === '5') openModStore();
        else if(map[e.key]) setTab(map[e.key]);
    }
});

function closeAllModals() { document.querySelectorAll('.modal-overlay').forEach(el => el.style.display = 'none'); }

// --- 3. THEMES ---
function setTheme(mode) { localStorage.setItem('theme', mode); updateThemeUI(mode); }
function updateThemeUI(mode) {
    let apply = mode; if (mode === 'auto') apply = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', apply);
    document.querySelectorAll('.theme-btn').forEach(b => b.classList.remove('active'));
    const btn = document.querySelector(`.theme-btn[onclick="setTheme('${mode}')"]`);
    if (btn) btn.classList.add('active');
}
updateThemeUI(localStorage.getItem('theme') || 'dark');

// --- 4. CONSOLA INTERACTIVA ---
const term = new Terminal({ fontFamily: 'JetBrains Mono', theme: { background: '#00000000' }, fontSize: 13, cursorBlink: true });
const fitAddon = new FitAddon.FitAddon(); term.loadAddon(fitAddon); term.open(document.getElementById('terminal'));
term.writeln('\x1b[1;35m>>> AETHER PANEL V1.5.0 READY.\x1b[0m\r\n');

window.onresize = () => { if (document.getElementById('tab-console').classList.contains('active')) fitAddon.fit(); };
term.onData(d => socket.emit('command', d));
socket.on('console_data', d => term.write(d));
socket.on('logs_history', d => { term.write(d); setTimeout(() => fitAddon.fit(), 200); });

function sendConsoleCommand() {
    const input = document.getElementById('console-input');
    if (input && input.value.trim()) { socket.emit('command', input.value); input.value = ''; }
}

// --- 5. TIENDA DE MODS & BÚSQUEDA ---
const modsDB = [
    { name: "Jei", fullName: "Just Enough Items", url: "https://mediafilez.forgecdn.net/files/5936/206/jei-1.20.1-forge-15.3.0.4.jar", icon: "fa-book", color: "#2ecc71" },
    { name: "Iron Chests", fullName: "Iron Chests", url: "https://mediafilez.forgecdn.net/files/4670/664/ironchest-1.20.1-14.4.4.jar", icon: "fa-box", color: "#95a5a6" },
    { name: "JourneyMap", fullName: "JourneyMap", url: "https://mediafilez.forgecdn.net/files/5864/381/journeymap-1.20.1-5.9.18-forge.jar", icon: "fa-map", color: "#3498db" },
    { name: "Nature's Compass", fullName: "Nature's Compass", url: "https://mediafilez.forgecdn.net/files/4682/937/NaturesCompass-1.20.1-1.11.2-forge.jar", icon: "fa-compass", color: "#27ae60" },
    { name: "Clumps", fullName: "Clumps (Lag Fix)", url: "https://mediafilez.forgecdn.net/files/4603/862/Clumps-forge-1.20.1-12.0.0.3.jar", icon: "fa-users", color: "#e67e22" },
    { name: "Waystones", fullName: "Waystones", url: "https://mediafilez.forgecdn.net/files/4609/279/waystones-forge-1.20.1-14.0.1.jar", icon: "fa-location-dot", color: "#8e44ad" },
    { name: "Biomes O' Plenty", fullName: "Biomes O' Plenty", url: "https://mediafilez.forgecdn.net/files/4763/368/BiomesOPlenty-1.20.1-18.0.0.598.jar", icon: "fa-tree", color: "#27ae60" }
];

function openModStore() {
    currentStoreMode = 'mods';
    const m = document.getElementById('version-modal'); m.style.display = 'flex';
    document.getElementById('version-list').innerHTML = '';
    m.querySelector('.modal-header h3').innerHTML = '<i class="fa-solid fa-store"></i> Mod Store';
    const searchInput = document.getElementById('store-search');
    if(searchInput) { searchInput.value = ''; searchInput.focus(); }
    renderMods(modsDB);
}

function renderMods(list) {
    const container = document.getElementById('version-list'); container.innerHTML = '';
    list.forEach(mod => {
        const el = document.createElement('div'); el.className = 'mod-card-modern'; el.style.setProperty('--mod-color', mod.color);
        el.innerHTML = `<div class="mod-card-header"><i class="fa-solid ${mod.icon}"></i></div><div class="mod-card-body"><h4>${mod.name}</h4><p>${mod.fullName}</p><button class="btn-install"><i class="fa-solid fa-download"></i> Instalar</button></div>`;
        el.onclick = () => { if (confirm(`¿Instalar ${mod.fullName}?`)) { api('mods/install', { url: mod.url, name: mod.name }); closeAllModals(); } };
        container.appendChild(el);
    });
}

const storeSearch = document.getElementById('store-search');
if(storeSearch) {
    storeSearch.oninput = (e) => {
        const term = e.target.value.toLowerCase();
        if (currentStoreMode === 'mods') renderMods(modsDB.filter(m => m.name.toLowerCase().includes(term)));
        else renderVersions(allVersions.filter(v => v.id.toLowerCase().includes(term)));
    };
}

// --- 6. GESTIÓN DE VERSIONES ---
async function loadVersions(type) {
    currentStoreMode = 'versions';
    const m = document.getElementById('version-modal'); m.style.display = 'flex';
    document.getElementById('version-list').innerHTML = '';
    m.querySelector('.modal-header h3').innerHTML = '<i class="fa-solid fa-cloud"></i> Repositorio';
    const loading = document.getElementById('loading-text');
    if(loading) loading.style.display = 'inline';
    try { allVersions = await api('nebula/versions', { type }); renderVersions(allVersions); } catch (e) { Toastify({ text: 'Error API', style: { background: '#ef4444' } }).showToast(); }
    if(loading) loading.style.display = 'none';
}

function renderVersions(list) {
    const g = document.getElementById('version-list'); g.innerHTML = '';
    list.forEach(v => {
        const e = document.createElement('div'); e.className = 'version-item';
        e.innerHTML = `<h4>${v.id}</h4><span>${v.type}</span>`; e.onclick = () => installVersion(v); g.appendChild(e);
    });
}

// --- INSTALADOR ROBUSTO ---
let pendingInstall = null;
async function installVersion(v) {
    pendingInstall = v; document.getElementById('version-modal').style.display = 'none';
    try {
        const s = await fetch('/api/stats').then(r => r.json());
        const m = Math.floor(s.ram_total / 1024 / 1024 / 1024);
        const slider = document.getElementById('ram-slider');
        if(slider) { slider.max = m; slider.value = Math.min(4, m); }
        const sysRam = document.getElementById('sys-ram-total');
        if(sysRam) sysRam.innerText = m.toFixed(1);
    } catch (e) { }
    document.getElementById('ram-modal').style.display = 'flex';
}
function updateRamDisplay(v) { document.getElementById('ram-display-val').innerText = v; }
function closeRamModal() { document.getElementById('ram-modal').style.display = 'none'; pendingInstall = null; }

async function confirmInstall() {
    if (!pendingInstall) return;
    const ram = document.getElementById('ram-slider').value;
    const v = pendingInstall; closeRamModal();
    let url = '';
    Toastify({ text: 'Obteniendo enlace...', style: { background: '#3b82f6' } }).showToast();
    try {
        if (v.type === 'vanilla') { const res = await api('nebula/resolve-vanilla', { url: v.url }); if (res && res.url) url = res.url; else throw new Error(); } 
        else if (v.type === 'paper') { const r = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${v.id}`); if (!r.ok) throw new Error(); const d = await r.json(); const b = d.builds[d.builds.length - 1]; url = `https://api.papermc.io/v2/projects/paper/versions/${v.id}/builds/${b}/downloads/paper-${v.id}-${b}.jar`; } 
        else if (v.type === 'fabric') { const r = await fetch('https://meta.fabricmc.net/v2/versions/loader'); const d = await r.json(); url = `https://meta.fabricmc.net/v2/versions/loader/${v.id}/${d[0].version}/1.0.1/server/jar`; } 
        else if (v.type === 'forge') { const res = await api('nebula/resolve-forge', { version: v.id }); if (res && res.url) url = res.url; else throw new Error(); }
        if (url) { await api('settings', { ram: ram + 'G' }); let filename = 'server.jar'; if (v.type === 'forge') filename = 'forge-installer.jar'; api('install', { url, filename }); Toastify({ text: 'Descarga iniciada...', style: { background: '#10b981' } }).showToast(); }
    } catch (e) { Toastify({ text: 'Error versión', style: { background: '#ef4444' } }).showToast(); }
}

// --- MONITOR & CHARTS ---
const createChart = (ctx, color, maxVal = 100) => new Chart(ctx, { type: 'line', data: { labels: Array(20).fill(''), datasets: [{ data: Array(20).fill(0), borderColor: color, backgroundColor: color + '15', fill: true, tension: 0.4, pointRadius: 0, borderWidth: 2 }] }, options: { responsive: true, maintainAspectRatio: false, animation: { duration: 0 }, scales: { x: { display: false }, y: { min: 0, max: maxVal, grid: { display: false, drawBorder: false }, ticks: { display: false } } }, plugins: { legend: { display: false }, tooltip: { enabled: false } } } });
const cpuChart = createChart(document.getElementById('cpuChart').getContext('2d'), '#8b5cf6', 100);
const ramChart = createChart(document.getElementById('ramChart').getContext('2d'), '#3b82f6', null);

setInterval(() => {
    fetch('/api/stats').then(r => r.json()).then(d => {
        cpuChart.data.datasets[0].data.shift(); cpuChart.data.datasets[0].data.push(d.cpu); cpuChart.update();
        document.getElementById('cpu-val').innerText = d.cpu.toFixed(1) + '%';
        document.getElementById('cpu-freq').innerText = d.cpu_freq + ' MHz';
        
        const toGB = (b) => (b / 1073741824).toFixed(1);
        const ramUsed = toGB(d.ram_used), ramTotal = toGB(d.ram_total), ramFree = toGB(d.ram_free);
        ramChart.options.scales.y.max = parseFloat(ramTotal); ramChart.data.datasets[0].data.shift(); ramChart.data.datasets[0].data.push(parseFloat(ramUsed)); ramChart.update();
        document.getElementById('ram-val').innerText = `${ramUsed} / ${ramTotal} GB`;
        document.getElementById('ram-free').innerText = ramFree + ' GB Libre';

        const diskMB = (d.disk_used / 1048576).toFixed(0);
        document.getElementById('disk-val').innerText = diskMB + ' MB';
        const diskPercent = Math.min((d.disk_used / d.disk_total) * 100, 100);
        document.getElementById('disk-fill').style.width = diskPercent + '%';
        
        socket.on('status_change', s => { const w = document.getElementById('status-widget'); if(w) { w.className = 'status-widget ' + s; document.getElementById('status-text').innerText = s; } });
    }).catch(() => { });
}, 1000);

// --- UTILIDADES ---
function setTab(t, btn) {
    document.querySelectorAll('.tab-content').forEach(e => e.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(e => e.classList.remove('active'));
    document.getElementById('tab-' + t).classList.add('active');
    if (btn) btn.classList.add('active'); else {
        const map = { 'stats':0, 'console':1, 'files':2, 'versions':3, 'backups':5, 'labs':6, 'config':7 };
        if(map[t] !== undefined) document.querySelectorAll('.nav-btn')[map[t]].classList.add('active');
    }
    if (t === 'console') setTimeout(() => { fitAddon.fit(); const i = document.getElementById('console-input'); if(i) i.focus(); }, 100);
    if (t === 'files') loadFileBrowser(''); if (t === 'config') loadCfg(); if (t === 'backups') loadBackups();
}
function api(ep, body) { return fetch('/api/' + ep, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then(r => r.json()); }

// --- FILE MANAGER, BACKUPS ---
function loadFileBrowser(p){ currentPath=p; document.getElementById('file-breadcrumb').innerText='/root'+(p?'/'+p:''); api('files?path='+encodeURIComponent(p)).then(fs=>{ const l=document.getElementById('file-list'); l.innerHTML=''; if(p){ const b=document.createElement('div'); b.className='file-row'; b.innerHTML='<span>..</span>'; b.onclick=()=>{ const a=p.split('/'); a.pop(); loadFileBrowser(a.join('/')) }; l.appendChild(b) } fs.forEach(f=>{ const e=document.createElement('div'); e.className='file-row'; e.innerHTML=`<span><i class="fa-solid ${f.isDir?'fa-folder':'fa-file'}"></i> ${f.name}</span><span>${f.size}</span>`; if(f.isDir)e.onclick=()=>loadFileBrowser((p?p+'/':'')+f.name); else e.onclick=()=>openEditor((p?p+'/':'')+f.name); l.appendChild(e) }) }) }
function uploadFile(){ const i=document.createElement('input'); i.type='file'; i.onchange=(e)=>{const f=new FormData();f.append('file',e.target.files[0]);fetch('/api/files/upload',{method:'POST',body:f}).then(r=>r.json()).then(d=>{if(d.success)loadFileBrowser(currentPath)})}; i.click() }
const ed=ace.edit("ace-editor"); ed.setTheme("ace/theme/dracula"); ed.setOptions({fontSize:"14px"});
function openEditor(f){ currentFile=f; api('files/read',{file:f}).then(d=>{ if(!d.error){ document.getElementById('editor-modal').style.display='flex'; ed.setValue(d.content,-1); } }) }
function saveFile(){ api('files/save',{file:currentFile,content:ed.getValue()}).then(()=>{document.getElementById('editor-modal').style.display='none'}) }
function closeEditor(){ document.getElementById('editor-modal').style.display='none' }
function loadBackups(){ api('backups').then(b=>{ const l=document.getElementById('backup-list'); l.innerHTML=''; b.forEach(k=>{ const e=document.createElement('div'); e.className='file-row'; e.innerHTML=`<span>${k.name}</span><div><button class="btn btn-sm" onclick="restoreBackup('${k.name}')">Restaurar</button><button class="btn btn-sm stop" onclick="deleteBackup('${k.name}')">X</button></div>`; l.appendChild(e) }) }) }
function createBackup(){ api('backups/create').then(()=>setTimeout(loadBackups,2000)) }
function deleteBackup(n){ if(confirm('¿Borrar?'))api('backups/delete',{name:n}).then(loadBackups) }
function restoreBackup(n){ if(confirm('¿Restaurar?'))api('backups/restore',{name:n}) }

// --- CONFIGURACIÓN & TOOLTIPS (DICCIONARIO COMPLETO) ---
const propDesc = {
    // BÁSICOS
    'online-mode': 'ACTIVADO: Solo cuentas Premium (Mojang).\nDESACTIVADO: Permite cuentas No-Premium (Crackeado).',
    'motd': 'El mensaje que aparece debajo del nombre del servidor en la lista multijugador.',
    'max-players': 'Número máximo de jugadores que pueden entrar al mismo tiempo.',
    'server-port': 'Puerto de conexión (Por defecto 25565).',
    'server-ip': 'Déjalo vacío para usar todas las IPs disponibles (Recomendado).',
    'enable-status': 'Si está desactivado, el servidor aparecerá como "Offline" en la lista.',
    'hide-online-players': 'Oculta la lista de jugadores al pasar el ratón en el menú.',

    // JUGABILIDAD
    'gamemode': 'Modo de juego por defecto: survival, creative, adventure, spectator.',
    'force-gamemode': 'Si se activa, obliga a los jugadores a usar el modo por defecto al entrar.',
    'difficulty': 'Dificultad: peaceful, easy, normal, hard.',
    'hardcore': 'Si se activa, los jugadores son baneados al morir (Modo Extremo).',
    'pvp': 'Si está activo, los jugadores pueden hacerse daño entre sí.',
    'allow-flight': 'Permite volar en modo supervivencia (Anti-Kick).',
    'player-idle-timeout': 'Minutos para expulsar a jugadores ausentes (AFK). 0 desactiva.',
    
    // MUNDO
    'level-seed': 'Semilla para generar el mundo.',
    'level-name': 'Nombre de la carpeta del mundo.',
    'level-type': 'Tipo de mapa: minecraft:normal, flat, large_biomes, amplified.',
    'generate-structures': 'Generar aldeas, fortalezas, etc.',
    'allow-nether': 'Permite viajar al Nether.',
    'spawn-protection': 'Radio de bloques protegidos en el Spawn.',
    'max-world-size': 'Radio máximo del mundo (Borde).',
    'max-build-height': 'Altura máxima de construcción.',
    'view-distance': 'Distancia de renderizado (chunks). Menos = Menos Lag.',
    'simulation-distance': 'Distancia de actualización de entidades/cultivos.',

    // TÉCNICO
    'white-list': 'Solo jugadores en lista blanca pueden entrar.',
    'enforce-whitelist': 'Expulsa a jugadores conectados si no están en la lista blanca.',
    'enable-command-block': 'Permite bloques de comandos.',
    'enable-rcon': 'Habilita acceso remoto a la consola.',
    'rcon.port': 'Puerto RCON.',
    'rcon.password': 'Contraseña RCON.',
    'rate-limit': 'Límite de paquetes (Anti-Spam). 0 desactiva.',
    'network-compression-threshold': 'Compresión de paquetes. Recomendado: 256.',
    'max-tick-time': 'Tiempo máximo por tick antes de cerrar (Watchdog). -1 desactiva.',
    'sync-chunk-writes': 'Escritura síncrona de chunks (Más seguro, más lento).',
    
    // RECURSOS
    'resource-pack': 'URL directa del paquete de recursos.',
    'require-resource-pack': 'Desconecta si rechazan el paquete de recursos.'
};

function loadCfg() { 
    fetch('/api/config').then(r => r.json()).then(d => { 
        const c = document.getElementById('cfg-list'); 
        c.innerHTML = ''; 
        
        if(Object.keys(d).length === 0) { 
            c.innerHTML = '<p style="color:var(--muted);text-align:center;padding:20px;">⚠️ Inicia el servidor una vez para generar el archivo server.properties</p>'; 
            return; 
        }

        const entries = Object.entries(d).sort((a,b) => a[0] === 'online-mode' ? -1 : 1);

        for(const [k, v] of entries) {
            // Buscar descripción o poner genérica si no existe
            const desc = propDesc[k] || 'Configuración avanzada.';
            const tooltip = `<span class="help-icon" data-tooltip="${desc}">?</span>`;
            
            let displayKey = k; 
            if(k === 'online-mode') displayKey = 'Modo Premium (Online Mode)';

            if(v === 'true' || v === 'false') {
                const ch = v === 'true'; 
                const lbl = ch ? 'Activado' : 'Desactivado'; 
                
                c.innerHTML += `
                <div class="cfg-item">
                    <label class="cfg-label" style="display:flex;align-items:center">
                        ${displayKey} ${tooltip}
                    </label>
                    <div class="cfg-switch-wrapper">
                        <span style="font-size:0.8rem;color:var(--muted)">${lbl}</span>
                        <label class="switch">
                            <input type="checkbox" class="cfg-bool" data-k="${k}" ${ch?'checked':''} 
                                   onchange="this.parentElement.previousElementSibling.innerText=this.checked?'Activado':'Desactivado'">
                            <span class="slider round"></span>
                        </label>
                    </div>
                </div>`;
            } else {
                c.innerHTML += `
                <div class="cfg-item">
                    <label class="cfg-label" style="display:flex;align-items:center">
                        ${k} ${tooltip}
                    </label>
                    <input type="text" class="cfg-in" data-k="${k}" value="${v}">
                </div>`;
            }
        } 
    }).catch(e => console.error("Error cargando config:", e));
}

function saveCfg() { 
    const d = {}; 
    document.querySelectorAll('.cfg-in').forEach(i => d[i.dataset.k] = i.value); 
    document.querySelectorAll('.cfg-bool').forEach(i => d[i.dataset.k] = i.checked ? 'true' : 'false');
    api('config', d); 
    Toastify({text:'Configuración Guardada', style:{background:'#10b981'}}).showToast(); 
}

// --- UPDATER (Mantenemos igual) ---
checkUpdate(true);
function checkUpdate(isAuto = false) {
    if (!isAuto) Toastify({ text: 'Buscando actualizaciones...', style: { background: 'var(--p)' } }).showToast();
    fetch('/api/update/check').then(r => r.json()).then(d => {
        if (d.type !== 'none') showUpdateModal(d);
        else if (!isAuto) Toastify({ text: 'Sistema actualizado', style: { background: '#10b981' } }).showToast();
    }).catch(e => { if (!isAuto) Toastify({ text: 'Error GitHub', style: { background: '#ef4444' } }).showToast(); });
}
function showUpdateModal(d) {
    const m = document.getElementById('update-modal');
    if(!m) return;
    const t = document.getElementById('update-text');
    const a = document.getElementById('up-actions');
    const ti = document.getElementById('up-title');
    if (d.type === 'hard') {
        ti.innerText = "Actualización Mayor";
        t.innerText = `Versión local: ${d.local}\nNueva versión: ${d.remote}\n\nSe requiere reinicio.`;
        a.innerHTML = `<button onclick="doUpdate('hard')" class="btn btn-primary">ACTUALIZAR</button><button onclick="document.getElementById('update-modal').style.display='none'" class="btn btn-ghost">Cancelar</button>`;
        m.style.display = 'flex';
    }
}
function doUpdate(type) {
    document.getElementById('update-modal').style.display = 'none';
    fetch('/api/update/perform', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ type }) }).then(r => r.json()).then(d => {
        if (d.mode === 'soft') { Toastify({ text: 'Aplicado.', style: { background: '#10b981' } }).showToast(); setTimeout(() => location.reload(), 1500); }
        if (d.mode === 'hard') { Toastify({ text: 'Reiniciando...', style: { background: '#f59e0b' } }).showToast(); setTimeout(() => location.reload(), 8000); }
    });
}
// --- NUEVA LÓGICA PARA FORZAR ACTUALIZACIÓN UI (Con Modal Bonito) ---
// 1. Esta función solo abre el modal de confirmación
function forceUIUpdate() {
    document.getElementById('force-ui-modal').style.display = 'flex';
}

// 2. Esta función se ejecuta al dar click en "CONFIRMAR Y ACTUALIZAR" en el modal
function confirmForceUI() {
    // Cerramos el modal primero
    document.getElementById('force-ui-modal').style.display = 'none';

    Toastify({text: 'Descargando interfaz...', style:{background:'#8b5cf6'}}).showToast();
    
    // Llamamos al endpoint con type: 'soft' para forzar la bajada de assets
    fetch('/api/update/perform', { 
        method: 'POST', 
        headers: { 'Content-Type': 'application/json' }, 
        body: JSON.stringify({ type: 'soft' }) 
    })
    .then(r => r.json())
    .then(d => {
        if (d.success) { 
            Toastify({ text: '¡Interfaz actualizada! Recargando...', style: { background: '#10b981' } }).showToast(); 
            setTimeout(() => location.reload(), 1500); 
        } else {
            throw new Error(d.error || 'Error desconocido');
        }
    })
    .catch(e => {
        console.error(e);
        Toastify({ text: 'Error al actualizar UI', style: { background: '#ef4444' } }).showToast(); 
    });
}
