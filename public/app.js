const socket = io();
let currentPath = '', currentFile = '', allVersions = [];
let currentStoreMode = 'versions'; // Para saber si buscamos versiones o mods

// --- 1. INFO & INICIO ---
fetch('/api/info').then(r => r.json()).then(d => {
    document.getElementById('sidebar-version-text').innerText = 'V' + d.version;
    document.getElementById('header-version').innerText = 'V' + d.version;
});

// --- 2. SHORTCUTS & NAVEGACIÓN (NUEVO V1.5) ---
document.addEventListener('keydown', (e) => {
    // Tecla ESC para cerrar modales
    if (e.key === 'Escape') closeAllModals();
    
    // Atajos ALT + Número para pestañas
    if (e.altKey && !e.ctrlKey && !e.shiftKey) {
        switch(e.key) {
            case '1': setTab('stats'); break;
            case '2': setTab('console'); break;
            case '3': setTab('files'); break;
            case '4': setTab('versions'); break;
            case '5': openModStore(); break;
            case '6': setTab('backups'); break;
            case '7': setTab('labs'); break;
            case '8': setTab('config'); break;
        }
    }
});

function closeAllModals() {
    document.querySelectorAll('.modal-overlay').forEach(el => el.style.display = 'none');
}

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

// --- 4. CONSOLA INTERACTIVA (MEJORADA V1.5) ---
const term = new Terminal({ fontFamily: 'JetBrains Mono', theme: { background: '#00000000' }, fontSize: 13, cursorBlink: true });
const fitAddon = new FitAddon.FitAddon(); 
term.loadAddon(fitAddon); 
term.open(document.getElementById('terminal'));
term.writeln('\x1b[1;35m>>> AETHER PANEL V1.5.0 READY.\x1b[0m\r\n');

window.onresize = () => { if (document.getElementById('tab-console').classList.contains('active')) fitAddon.fit(); };
term.onData(d => socket.emit('command', d)); // Escritura directa en la caja negra
socket.on('console_data', d => term.write(d));
socket.on('logs_history', d => { term.write(d); setTimeout(() => fitAddon.fit(), 200); });

// Nueva función para el input de texto inferior (si lo usas en el HTML)
function sendConsoleCommand() {
    const input = document.getElementById('console-input');
    if (input && input.value.trim()) {
        socket.emit('command', input.value);
        input.value = '';
    }
}

// --- 5. TIENDA DE MODS & BÚSQUEDA (MEJORADA V1.5) ---
const modsDB = [
    { name: "Jei", fullName: "Just Enough Items", url: "https://mediafilez.forgecdn.net/files/5936/206/jei-1.20.1-forge-15.3.0.4.jar", icon: "fa-book", color: "#2ecc71" },
    { name: "Iron Chests", fullName: "Iron Chests", url: "https://mediafilez.forgecdn.net/files/4670/664/ironchest-1.20.1-14.4.4.jar", icon: "fa-box", color: "#95a5a6" },
    { name: "JourneyMap", fullName: "JourneyMap", url: "https://mediafilez.forgecdn.net/files/5864/381/journeymap-1.20.1-5.9.18-forge.jar", icon: "fa-map", color: "#3498db" },
    { name: "Nature's Compass", fullName: "Nature's Compass", url: "https://mediafilez.forgecdn.net/files/4682/937/NaturesCompass-1.20.1-1.11.2-forge.jar", icon: "fa-compass", color: "#27ae60" },
    { name: "Clumps", fullName: "Clumps (Lag Fix)", url: "https://mediafilez.forgecdn.net/files/4603/862/Clumps-forge-1.20.1-12.0.0.3.jar", icon: "fa-users", color: "#e67e22" },
    { name: "Waystones", fullName: "Waystones", url: "https://mediafilez.forgecdn.net/files/4609/279/waystones-forge-1.20.1-14.0.1.jar", icon: "fa-location-dot", color: "#8e44ad" }
];

function openModStore() {
    currentStoreMode = 'mods';
    const m = document.getElementById('version-modal');
    m.style.display = 'flex';
    document.getElementById('version-list').innerHTML = '';
    m.querySelector('.modal-header h3').innerHTML = '<i class="fa-solid fa-store"></i> Mod Store';
    
    // Limpiar y enfocar buscador
    const searchInput = document.getElementById('version-search') || document.getElementById('store-search');
    if(searchInput) { searchInput.value = ''; searchInput.focus(); }
    
    renderMods(modsDB);
}

function renderMods(list) {
    const container = document.getElementById('version-list');
    container.innerHTML = '';
    list.forEach(mod => {
        const el = document.createElement('div');
        el.className = 'mod-card-modern';
        el.style.setProperty('--mod-color', mod.color);
        el.innerHTML = `
            <div class="mod-card-header"><i class="fa-solid ${mod.icon}"></i></div>
            <div class="mod-card-body"><h4>${mod.name}</h4><p>${mod.fullName}</p><button class="btn-install"><i class="fa-solid fa-download"></i> Instalar</button></div>
        `;
        el.onclick = () => {
            if (confirm(`¿Instalar ${mod.fullName}?`)) {
                api('mods/install', { url: mod.url, name: mod.name });
                closeAllModals();
            }
        };
        container.appendChild(el);
    });
}

// Búsqueda Inteligente (Versiones y Mods)
const searchInput = document.getElementById('version-search'); // Asegúrate que tu HTML tenga este ID
if(searchInput) {
    searchInput.oninput = (e) => {
        const term = e.target.value.toLowerCase();
        if (currentStoreMode === 'mods') {
            renderMods(modsDB.filter(m => m.name.toLowerCase().includes(term)));
        } else {
            renderVersions(allVersions.filter(v => v.id.toLowerCase().includes(term)));
        }
    };
}

// --- 6. GESTIÓN DE VERSIONES ---
async function loadVersions(type) {
    currentStoreMode = 'versions';
    const m = document.getElementById('version-modal'); 
    m.style.display = 'flex'; 
    document.getElementById('version-list').innerHTML = '';
    m.querySelector('.modal-header h3').innerHTML = '<i class="fa-solid fa-cloud"></i> Repositorio';
    
    // Mostrar loading
    const loading = document.getElementById('loading-text');
    if(loading) loading.style.display = 'inline';

    try { 
        allVersions = await api('nebula/versions', { type }); 
        renderVersions(allVersions); 
    } catch (e) { Toastify({ text: 'Error API', style: { background: '#ef4444' } }).showToast(); }
    
    if(loading) loading.style.display = 'none';
}

function renderVersions(list) {
    const g = document.getElementById('version-list');
    g.innerHTML = '';
    list.forEach(v => {
        const e = document.createElement('div');
        e.className = 'version-item';
        e.innerHTML = `<h4>${v.id}</h4><span>${v.type}</span>`;
        e.onclick = () => installVersion(v);
        g.appendChild(e);
    });
}

// --- INSTALADOR ROBUSTO (Soluciona "Error Version") ---
let pendingInstall = null;
async function installVersion(v) {
    pendingInstall = v;
    document.getElementById('version-modal').style.display = 'none';
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
    const slider = document.getElementById('ram-slider');
    const ram = slider ? slider.value : '4';
    const v = pendingInstall;
    closeRamModal();
    
    let url = '';
    Toastify({ text: 'Obteniendo enlace...', style: { background: '#3b82f6' } }).showToast();

    try {
        if (v.type === 'vanilla') {
            const res = await api('nebula/resolve-vanilla', { url: v.url });
            if (res && res.url) url = res.url; else throw new Error();
        } 
        else if (v.type === 'paper') {
            const r = await fetch(`https://api.papermc.io/v2/projects/paper/versions/${v.id}`);
            if (!r.ok) throw new Error();
            const d = await r.json();
            const b = d.builds[d.builds.length - 1];
            url = `https://api.papermc.io/v2/projects/paper/versions/${v.id}/builds/${b}/downloads/paper-${v.id}-${b}.jar`;
        } 
        else if (v.type === 'fabric') {
            const r = await fetch('https://meta.fabricmc.net/v2/versions/loader');
            const d = await r.json();
            url = `https://meta.fabricmc.net/v2/versions/loader/${v.id}/${d[0].version}/1.0.1/server/jar`;
        } 
        else if (v.type === 'forge') {
            const res = await api('nebula/resolve-forge', { version: v.id });
            if (res && res.url) url = res.url; else throw new Error();
        }

        if (url) {
            await api('settings', { ram: ram + 'G' });
            let filename = 'server.jar';
            if (v.type === 'forge') filename = 'forge-installer.jar';
            api('install', { url, filename });
            Toastify({ text: 'Descarga iniciada...', style: { background: '#10b981' } }).showToast();
        }
    } catch (e) {
        console.error(e);
        Toastify({ text: 'Error al obtener versión', style: { background: '#ef4444' } }).showToast();
    }
}

// --- MONITOR & CHARTS (GB + Escala Fija) ---
const createChart = (ctx, color, maxVal = 100) => new Chart(ctx, { 
    type: 'line', 
    data: { 
        labels: Array(20).fill(''), 
        datasets: [{ data: Array(20).fill(0), borderColor: color, backgroundColor: color + '15', fill: true, tension: 0.4, pointRadius: 0, borderWidth: 2 }] 
    }, 
    options: { 
        responsive: true, maintainAspectRatio: false, animation: { duration: 0 }, 
        scales: { x: { display: false }, y: { min: 0, max: maxVal, grid: { display: false, drawBorder: false }, ticks: { display: false } } }, 
        plugins: { legend: { display: false }, tooltip: { enabled: false } } 
    } 
});

const cpuChart = createChart(document.getElementById('cpuChart').getContext('2d'), '#8b5cf6', 100);
const ramChart = createChart(document.getElementById('ramChart').getContext('2d'), '#3b82f6', null);

setInterval(() => {
    fetch('/api/stats').then(r => r.json()).then(d => {
        // CPU
        cpuChart.data.datasets[0].data.shift(); cpuChart.data.datasets[0].data.push(d.cpu); cpuChart.update();
        document.getElementById('cpu-val').innerText = d.cpu.toFixed(1) + '%';
        document.getElementById('cpu-freq').innerText = d.cpu_freq + ' MHz';

        // RAM (GB)
        const toGB = (bytes) => (bytes / (1024 * 1024 * 1024)).toFixed(1);
        const ramUsedGB = toGB(d.ram_used);
        const ramTotalGB = toGB(d.ram_total);
        const ramFreeGB = toGB(d.ram_free);

        ramChart.options.scales.y.max = parseFloat(ramTotalGB);
        ramChart.data.datasets[0].data.shift(); ramChart.data.datasets[0].data.push(parseFloat(ramUsedGB)); ramChart.update();
        
        document.getElementById('ram-val').innerText = `${ramUsedGB} / ${ramTotalGB} GB`;
        document.getElementById('ram-free').innerText = ramFreeGB + ' GB Libre';

        // Disco
        const diskMB = (d.disk_used / (1024 * 1024)).toFixed(0);
        document.getElementById('disk-val').innerText = diskMB + ' MB';
        const diskPercent = Math.min((d.disk_used / d.disk_total) * 100, 100);
        document.getElementById('disk-fill').style.width = diskPercent + '%';
        
        // Estado Socket
        socket.on('status_change', s => { 
            const widget = document.getElementById('status-widget');
            if(widget) { widget.className = 'status-widget ' + s; document.getElementById('status-text').innerText = s; }
        });

    }).catch(() => { });
}, 1000);

// --- UTILIDADES DE INTERFAZ ---
function setTab(t, btn) {
    document.querySelectorAll('.tab-content').forEach(e => e.classList.remove('active'));
    document.querySelectorAll('.nav-btn').forEach(e => e.classList.remove('active'));
    document.getElementById('tab-' + t).classList.add('active');
    
    if (btn) btn.classList.add('active');
    else {
        // Activar botón lateral por índice si se usa atajo
        const map = { 'stats':0, 'console':1, 'files':2, 'versions':3, 'backups':5, 'labs':6, 'config':7 };
        if(map[t] !== undefined) document.querySelectorAll('.nav-btn')[map[t]].classList.add('active');
    }

    if (t === 'console') setTimeout(() => { 
        fitAddon.fit(); 
        const input = document.getElementById('console-input');
        if(input) input.focus(); 
    }, 100);
    if (t === 'files') loadFileBrowser('');
    if (t === 'config') loadCfg();
    if (t === 'backups') loadBackups();
}

// --- API GENÉRICA ---
function api(ep, body) { return fetch('/api/' + ep, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }).then(r => r.json()); }

// --- FILE MANAGER ---
function loadFileBrowser(p) { currentPath = p; document.getElementById('file-breadcrumb').innerText = '/root' + (p ? '/' + p : ''); api('files?path=' + encodeURIComponent(p)).then(fs => { const l = document.getElementById('file-list'); l.innerHTML = ''; if (p) { const b = document.createElement('div'); b.className = 'file-row'; b.innerHTML = '<span>..</span>'; b.onclick = () => { const a = p.split('/'); a.pop(); loadFileBrowser(a.join('/')) }; l.appendChild(b) } fs.forEach(f => { const e = document.createElement('div'); e.className = 'file-row'; e.innerHTML = `<span><i class="fa-solid ${f.isDir ? 'fa-folder' : 'fa-file'}"></i> ${f.name}</span><span>${f.size}</span>`; if (f.isDir) e.onclick = () => loadFileBrowser((p ? p + '/' : '') + f.name); else e.onclick = () => openEditor((p ? p + '/' : '') + f.name); l.appendChild(e) }) }) }
function uploadFile() { const i = document.createElement('input'); i.type = 'file'; i.onchange = (e) => { const f = new FormData(); f.append('file', e.target.files[0]); fetch('/api/files/upload', { method: 'POST', body: f }).then(r => r.json()).then(d => { if (d.success) loadFileBrowser(currentPath) }) }; i.click() }
const ed = ace.edit("ace-editor"); ed.setTheme("ace/theme/dracula"); ed.setOptions({ fontSize: "14px" });
function openEditor(f) { currentFile = f; api('files/read', { file: f }).then(d => { if (!d.error) { document.getElementById('editor-modal').style.display = 'flex'; ed.setValue(d.content, -1); } }) }
function saveFile() { api('files/save', { file: currentFile, content: ed.getValue() }).then(() => { document.getElementById('editor-modal').style.display = 'none' }) }
function closeEditor() { document.getElementById('editor-modal').style.display = 'none' }

// --- BACKUPS ---
function loadBackups() { api('backups').then(b => { const l = document.getElementById('backup-list'); l.innerHTML = ''; b.forEach(k => { const e = document.createElement('div'); e.className = 'file-row'; e.innerHTML = `<span>${k.name}</span><div><button class="btn btn-sm" onclick="restoreBackup('${k.name}')">Restaurar</button><button class="btn btn-sm stop" onclick="deleteBackup('${k.name}')">X</button></div>`; l.appendChild(e) }) }) }
function createBackup() { api('backups/create').then(() => setTimeout(loadBackups, 2000)) }
function deleteBackup(n) { if (confirm('¿Borrar?')) api('backups/delete', { name: n }).then(loadBackups) }
function restoreBackup(n) { if (confirm('¿Restaurar?')) api('backups/restore', { name: n }) }

// --- CONFIGURACIÓN (Switches) ---
function loadCfg() {
    fetch('/api/config').then(r => r.json()).then(d => {
        const c = document.getElementById('cfg-list'); c.innerHTML = '';
        if (Object.keys(d).length === 0) { c.innerHTML = '<p style="color:var(--muted);text-align:center;padding:20px;">⚠️ Inicia el servidor una vez para generar el archivo server.properties</p>'; return; }
        const entries = Object.entries(d).sort((a, b) => a[0] === 'online-mode' ? -1 : 1);
        for (const [k, v] of entries) {
            if (v === 'true' || v === 'false') {
                const ch = v === 'true'; const lbl = ch ? 'Activado' : 'Desactivado'; const dk = k === 'online-mode' ? 'Modo Premium (Online Mode)' : k;
                c.innerHTML += `<div class="cfg-item"><label class="cfg-label">${dk}</label><div class="cfg-switch-wrapper"><span style="font-size:0.8rem;color:var(--muted)">${lbl}</span><label class="switch"><input type="checkbox" class="cfg-bool" data-k="${k}" ${ch ? 'checked' : ''} onchange="this.parentElement.previousElementSibling.innerText=this.checked?'Activado':'Desactivado'"><span class="slider round"></span></label></div></div>`;
            } else {
                c.innerHTML += `<div class="cfg-item"><label class="cfg-label">${k}</label><input class="cfg-in" type="text" data-k="${k}" value="${v}"></div>`;
            }
        }
    })
}
function saveCfg() {
    const d = {};
    document.querySelectorAll('.cfg-in').forEach(i => d[i.dataset.k] = i.value);
    document.querySelectorAll('.cfg-bool').forEach(i => d[i.dataset.k] = i.checked ? 'true' : 'false');
    api('config', d); Toastify({ text: 'Configuración Guardada', style: { background: '#10b981' } }).showToast();
}

// --- UPDATER ---
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
