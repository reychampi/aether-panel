# 🌌 Aether Nebula v2.0 - Multi-Server Edition

El **Aether Nebula Panel** es una plataforma de gestión de servidores de Minecraft de última generación, diseñada para la administración **multi-instancia** en un entorno Node.js robusto. Permite la gestión dinámica de recursos, seguridad y tareas programadas para múltiples servidores alojados en una única máquina.

## ✨ Características Principales

| Característica | Descripción |
| :--- | :--- |
| **Multi-Server Instance** | Arquitectura basada en la clase `ServerInstance` que permite gestionar, iniciar y detener múltiples servidores de Minecraft de forma aislada. |
| **Gestión Dinámica de Puertos** | Utiliza `ufw` y la configuración de `sudoers` sin contraseña (`NOPASSWD`) para abrir y cerrar dinámicamente puertos de servidor durante el ciclo de vida de la instancia.  |
| **Módulos de Sistema Avanzados** | Integración modular para facilitar la gestión de mundos (`Worlds`), la programación de tareas (`Scheduler`), y la extensión con recursos externos (`Marketplace`). |
| **Marketplace Integrado** | Soporte para la búsqueda e instalación directa de *mods* y *plugins* desde plataformas como **Modrinth** y **CurseForge** (requiere API Key). |
| **Copias de Seguridad Inteligentes** | El módulo `Worlds` permite crear copias de seguridad (`.zip`) de un servidor, excluyendo archivos innecesarios como `logs/`, `cache/` o `node_modules/`. |
| **Scheduler (Tareas Programadas)** | Permite programar acciones recurrentes como reinicios, copias de seguridad o comandos específicos, utilizando la sintaxis **Cron**. |
| **Seguridad y Rendimiento** | Incluye autenticación basada en **JWT** y `bcrypt`, *rate limiting* con `express-rate-limit`, compresión (`compression`), y monitorización en tiempo real de CPU/RAM a través de `systeminformation`. |

## 📐 Arquitectura del Sistema (Backend Node.js)

El panel está construido sobre una estructura Node.js con Express y Socket.IO, utilizando una clara separación de responsabilidades:

### 1\. Núcleo del Panel (`server.js`)

  * **API (Express):** Define las rutas **REST** para la gestión de servidores (crear, eliminar), configuración, autenticación y administración de módulos.
  * **Websockets (Socket.IO):** Es el canal de comunicación en tiempo real.
      * **Logs:** Cada instancia de servidor emite sus logs a una "sala" específica de Socket.IO, permitiendo al frontend mostrar la consola en tiempo real.
      * **Rendimiento:** Envía estadísticas globales de CPU y memoria del host de forma periódica (`getPerformance`).
  * **Autenticación:** Utiliza `JWT` para la sesión y `bcrypt` para el almacenamiento seguro de contraseñas.

### 2\. Gestión de Servidores (`mc_server_manager.js`)

Esta es la clase central que gestiona la lógica multi-instancia.

  * **`MCServerManager` (Global):**
      * Gestiona el *pool* de instancias (`this.instances`).
      * Carga y persiste la configuración global del panel (`panel.json`).
      * Proporciona métodos globales como `listServers` y `getPerformance`.
  * **`ServerInstance` (Por Servidor):**
      * Representa un único servidor de Minecraft.
      * Gestiona su propio proceso de `spawn` (Java JAR), su estado (`online`/`offline`), configuración (`config.json`), y `logs`.
      * **Delegación de Módulos:** Cada instancia tiene su propia copia de los módulos `Worlds`, `Scheduler` y `Marketplace`, asegurando que las operaciones se realicen en la ruta base (`basePath`) correcta de ese servidor.

### 3\. Módulos de Soporte (`/modules`)

| Módulo | Clase principal | Responsabilidad |
| :--- | :--- | :--- |
| `updater.js` | `Updater` | Utiliza comandos **Git** (`git fetch`/`git pull`) para gestionar las actualizaciones del propio panel. |
| `worlds.js` | `Worlds` | Crea *backups* (usando `archiver`), restaura mundos (usando `unzip`), y resetea dimensiones (Nether/End). |
| `scheduler.js` | `Scheduler` | Programa tareas recurrentes (usando `node-schedule`) que interactúan con la `ServerInstance` inyectada. |
| `marketplace.js` | `Market` | Busca y descarga archivos (mods/plugins) desde APIs externas (Modrinth/CurseForge) directamente al directorio del servidor. |

## 🔒 Instalación y Seguridad

El script de instalación (`installserver.sh`) automatiza los siguientes pasos:

1.  **Aprovisionamiento:** Instala dependencias (`nodejs`, `npm`, `git`, `openjdk-XX`, `ufw`).
2.  **Usuario Dedicado:** Crea un usuario de sistema de bajo privilegio (`aetherpanel`) para ejecutar el panel.
3.  **Configuración de UFW:**
      * Abre el puerto **3000/tcp** para el acceso al panel.
      * Añade una regla `sudoers` que permite al usuario `aetherpanel` ejecutar comandos específicos de `ufw allow` y `ufw delete allow` **sin contraseña**. Esto es crucial para la gestión dinámica de puertos.
4.  **Despliegue:** Descarga el código base, configura las dependencias de Node.js, e instala y configura **PM2** para que el panel se ejecute como un servicio en segundo plano, asegurando alta disponibilidad.

-----

**Comenzar con el Panel Web:**

Una vez completada la instalación, el panel estará accesible en tu navegador:

➡️ **`http://[IP_DEL_SERVIDOR]:3000`**

Puedes verificar el estado del servicio con:

```bash
pm2 status
```

**¡Disfruta de la gestión de tus servidores\!**
