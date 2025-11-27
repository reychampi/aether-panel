<div align="center">

<img src="[https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.svg](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.svg)" alt="Aether Panel Logo" width="120" height="120">

# 🌌 Aether Panel

**El panel de control ligero, moderno y potente para servidores de Minecraft.**
Gestión inteligente, monitoreo en tiempo real y diseño Glassmorphism.

[![Version](https://img.shields.io/badge/version-1.4.3-8b5cf6?style=for-the-badge&logo=git)](https://github.com/reychampi/aether-panel)
[![Status](https://img.shields.io/badge/status-stable-10b981?style=for-the-badge)](https://github.com/reychampi/aether-panel)
[![Node.js](https://img.shields.io/badge/node-%3E%3D16-339933?style=for-the-badge&logo=node.js)](https://nodejs.org/)

[Instalación](#-instalación-rápida) • [Sistemas Compatibles](#-sistemas-operativos-soportados) • [Características](#-características)

</div>

---

## ✨ Descripción

**Aether Panel** es una solución todo-en-uno para administrar servidores de Minecraft en entornos Linux. Diseñado para ser visualmente impactante y técnicamente robusto, elimina la necesidad de configuraciones complejas por terminal, ofreciendo una interfaz web reactiva y fácil de usar.

![Dashboard Preview](https://raw.githubusercontent.com/reychampi/aether-panel/main/public/logo.png)

---

## 🐧 Sistemas Operativos Soportados

Aether Panel está optimizado para distribuciones basadas en **Debian** que utilicen `systemd`.

| Sistema Operativo | Versiones Recomendadas | Estado |
| :--- | :--- | :--- |
| **Ubuntu** | 20.04 LTS, 22.04 LTS, 24.04 LTS | ✅ **Nativo** |
| **Debian** | 10 (Buster), 11 (Bullseye), 12 (Bookworm) | ✅ **Nativo** |
| **Linux Mint** | 20+ | ⚠️ Compatible |
| **CentOS / RHEL** | 8+ | ❌ No Soportado (Script usa apt) |

---

## 🚀 Novedades V1.4.3

Esta versión consolida todas las mejoras de estabilidad y visualización.

### 🛠️ Correcciones Críticas (Core)
* **Instalación Universal:** Solucionado el error `$'\r': command not found` mediante conversión forzada a formato Linux (LF).
* **Servicio Robusto:** El panel ahora detecta automáticamente la ruta de instalación de `node` para evitar fallos en VPS con entornos personalizados.
* **Dependencias:** Añadido `rsync` al instalador para garantizar actualizaciones seguras sin pérdida de datos.
* **Descargas Inteligentes:** Nuevo sistema para obtener enlaces de descarga de **Forge, Fabric y Paper** sin errores de "Link not found".

### 🎨 Mejoras Visuales y UI
* **Gráficas Precisas:**
    * **RAM:** Visualización en **GB** reales con decimales limpios.
    * **CPU:** Escala fija (0-100%) para una lectura más natural del rendimiento.
    * **Disco:** Cálculo recursivo real del espacio ocupado por el servidor.
* **Editor de Configuración:**
    * El archivo `server.properties` ahora se muestra con **Interruptores (Switches)** para opciones como `online-mode` (Premium/Crackeado), PvP, Vuelo, etc.
    * Diseño alineado y limpio para todos los campos de configuración.

---

## 📦 Instalación Rápida

Accede a tu terminal como usuario `root` y ejecuta el siguiente comando mágico:

```bash
curl -sL https://raw.githubusercontent.com/reychampi/aether-panel/main/installserver.sh | bash
````

El instalador automático se encargará de:

1.  Instalar dependencias (Java, Node.js, Git, Zip, Rsync).
2.  Configurar el servicio automático `systemd` para que el panel se inicie solo.
3.  Descargar el núcleo del panel y los recursos gráficos.
4.  Iniciar el servicio en el puerto **3000**.

-----

## ⚡ Características

  * **🖥️ Monitor en Tiempo Real:** Gráficas de CPU, RAM y Disco con actualización por Sockets.
  * **💻 Consola Web:** Terminal en vivo con colores y envío de comandos.
  * **📂 Gestor de Archivos:** Editor de texto integrado (Ace Editor) con resaltado de sintaxis.
  * **📥 Instalador de Núcleos:** Descarga Vanilla, Paper, Fabric o Forge con un solo clic.
  * **📦 Sistema de Backups:** Crea y restaura copias de seguridad en segundos.
  * **🧩 Tienda de Mods:** Instalador rápido para mods populares (JEI, JourneyMap, etc.).
  * **⚙️ Configuración Visual:** Edita `server.properties` con una interfaz gráfica amigable.
  * **🔄 Smart Updater:** Sistema de actualizaciones OTA (Over-The-Air) integrado que protege tus datos.

-----

## 🛠️ Solución de Problemas Frecuentes

**El panel no carga en el navegador**
Asegúrate de que el puerto 3000 está abierto en tu firewall:

```bash
sudo ufw allow 3000/tcp
```

Si usas Oracle Cloud o AWS, abre también el puerto en el panel de seguridad de tu proveedor.

**Error "command not found" al instalar**
Si descargaste los archivos manualmente en Windows y los subiste, es posible que tengan formato incorrecto. Ejecuta en la carpeta del panel:

```bash
sed -i 's/\r$//' *.sh
```

-----

<div align="center">

Desarrollado por ReyChampi

</div>
