<div align="center">
<img src="https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png" alt="Aether Panel Logo" width="45" height="45"> # Aether Panel

**El panel de control ligero, moderno y potente para servidores de Minecraft.**
Gestión inteligente, monitoreo en tiempo real y diseño Glassmorphism.

[![Version](https://img.shields.io/badge/version-1.6.0-8b5cf6?style=for-the-badge&logo=git)](https://github.com/reychampi/aether-panel)
[![Status](https://img.shields.io/badge/status-stable-10b981?style=for-the-badge)](https://github.com/reychampi/aether-panel)
[![Node.js](https://img.shields.io/badge/node-%3E%3D16-339933?style=for-the-badge&logo=node.js)](https://nodejs.org/)
![Windows](https://img.shields.io/badge/Windows-Nativo-0078D6?style=for-the-badge&logo=windows)

[Instalación](#-instalación-rápida) • [Sistemas Compatibles](#-sistemas-operativos-soportados) • [Características](#-características)

</div>

---

## ✨ Descripción

**Aether Panel** es una solución todo-en-uno para administrar servidores de Minecraft. Diseñado para ser visualmente impactante y técnicamente robusto, elimina la necesidad de configuraciones complejas, ofreciendo una interfaz web reactiva y fácil de usar tanto en **Linux** como en **Windows**.

![Dashboard Preview](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/panel.png)

---

## 🐧 Sistemas Operativos Soportados

Aether Panel es ahora **Universal** y funciona nativamente en la mayoría de sistemas modernos.

| Familia | Distribuciones / SO | Método | Estado |
| :--- | :--- | :--- | :--- |
| **Debian** | Ubuntu 20.04+, Debian 10+, Mint | `apt` | ✅ **Nativo** |
| **RHEL** | Fedora 36+, CentOS 8+, Rocky | `dnf` | ✅ **Nativo** |
| **Arch** | Arch Linux, Manjaro | `pacman` | ✅ **Nativo** |
| **Windows** | Windows 10, 11, Server 2019+ | `.bat` | ✅ **Nativo** |

> ℹ️ **Nota para Windows:** Ya no es necesario usar WSL2. El panel se ejecuta directamente sobre Node.js en Windows.

---

## 🚀 Novedades V1.5.x

### 🎮 Experiencia de Usuario (UI/UX)
* **Consola Interactiva:** Envía comandos al servidor directamente desde la web.
* **Sistema de Ayuda:** Tooltips `(?)` explicativos en todas las opciones del `server.properties`.
* **Atajos de Teclado:** Navega rápido usando `Alt + 1-8` y cierra ventanas con `ESC`.
* **IP Copiable:** Haz clic en la IP de la cabecera para copiarla al portapapeles.

### 🛠️ Mejoras Técnicas
* **Soporte Windows Nativo:** Nuevo lanzador `start_windows.bat` que instala dependencias (Node/Java) automáticamente.
* **Instalador Linux Universal:** Detección automática de distro (Ubuntu/Fedora/Arch).
* **Actualizador UI:** Botón para forzar la actualización de la interfaz gráfica sin reiniciar.
* **Soporte de Temas:** Compatibilidad total con Modo Claro y Oscuro.
* **Resolución de Versiones:** Lógica mejorada para descargar Forge, Fabric y Paper.

---

## 📦 Instalación Rápida

### 🐧 En Linux (VPS/Dedicado)
Accede a tu terminal como usuario `root` y ejecuta:
curl -sL [https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh](https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh) | bash

🪟 En Windows (PC/Server)

    Descarga el código del repositorio (Botón Code > Download ZIP) y descomprímelo.

    Haz doble clic en el archivo start_windows.bat.

    El script instalará automáticamente Node.js y Java si no los tienes.

    El panel se abrirá automáticamente.

⚡ Características

    🖥️ Monitor en Tiempo Real: Gráficas de CPU, RAM y Disco.

    💻 Consola Web: Terminal en vivo con colores y envío de comandos.

    📂 Gestor de Archivos: Editor de texto integrado con resaltado de sintaxis.

    📥 Instalador de Núcleos: Vanilla, Paper, Fabric y Forge a un clic.

    📦 Backups: Sistema de copias de seguridad .tar.gz.

    🧩 Tienda de Mods: Buscador integrado para instalar mods populares.

    ⚙️ Configuración Visual: Edita server.properties con interruptores fáciles.

    🔄 Smart Updater: Sistema de actualizaciones OTA integrado.

🛠️ Solución de Problemas Frecuentes

El panel no carga en el navegador Asegúrate de abrir el puerto 3000 en tu firewall:

    Linux (UFW): sudo ufw allow 3000/tcp

    Windows: Asegúrate de dar permisos en la ventana emergente del Firewall de Windows al iniciar Node.js.

Error "command not found" o "$'\r'" (Linux) Si subiste los archivos manualmente desde Windows, es posible que tengan formato incorrecto. Ejecuta:
sed -i 's/\r$//' *.sh

<div align="center">

Desarrollado por ReyChampi Reportar un Bug

</div>
