====================================================
  AUREXMC NETWORK - LEEME PRIMERO
====================================================

Esto es una "network" (red) de Minecraft Java Edition
que se ejecuta en TU PC con Windows. No necesitas saber
programar para usarla: solo sigue estos pasos en orden.

----------------------------------------------------
1) QUE ES CADA CARPETA
----------------------------------------------------

AurexMC Network/
|
|-- INSTALL-AurexMC.bat   -> Instala todo (solo 1 vez)
|-- START-NETWORK.bat     -> Abre el panel de control y
|                            enciende los servidores
|-- STOP-NETWORK.bat      -> Apaga todo de emergencia
|-- README.txt            -> Este archivo
|
|-- Velocity/    -> El "proxy". Es la puerta de entrada
|                    unica de tu red (puerto 25565).
|                    Aqui se conectan los jugadores.
|
|-- Lobby/       -> Tu servidor de recepcion/lobby
|                    (puerto interno 25566).
|
|-- Survival/    -> Tu servidor de Survival
|                    (puerto interno 25567).
|
|-- tools/       -> Scripts internos (no los borres).
|
|-- plugins/     -> Contiene PLUGIN-PLAN.txt con la
                     lista de plugins y como instalarlos.

Los jugadores SIEMPRE se conectan al puerto de Velocity
(25565). Nunca deben conectarse directamente a Lobby o
Survival: esos puertos solo escuchan en 127.0.0.1 (tu
propio PC) por seguridad.

----------------------------------------------------
2) COMO INSTALAR (SOLO LA PRIMERA VEZ)
----------------------------------------------------

1. Asegurate de tener conexion a internet.
2. Haz doble clic en:  INSTALL-AurexMC.bat
3. Se abrira una ventana de PowerShell. Sigue las
   instrucciones en pantalla.
4. El instalador va a:
   - Comprobar que tienes Java 21.
   - Descargar Velocity y Paper (Lobby y Survival).
   - Crear la configuracion de todo.
   - Generar la clave secreta de conexion (forwarding).
   - Intentar descargar los plugins base (los que se
     puedan descargar de forma segura).
5. Cuando termine, veras un resumen en pantalla.

Si algo falla (por ejemplo, no tienes internet o Java
no es la version correcta), el instalador te lo dira
con un mensaje claro. No se creara ningun archivo falso.

----------------------------------------------------
3) COMO ACEPTAR LA EULA (OBLIGATORIO)
----------------------------------------------------

Minecraft exige que aceptes su acuerdo de licencia (EULA)
para poder usar el servidor. Por defecto viene en:

  eula=false

Para aceptarla:

1. Lee la EULA aqui:  https://aka.ms/MinecraftEULA
2. Abre con el Bloc de notas estos dos archivos:
   - Lobby\eula.txt
   - Survival\eula.txt
3. Cambia la linea "eula=false" por "eula=true"
4. Guarda los dos archivos.

Si no haces esto, Lobby y Survival no arrancaran.

----------------------------------------------------
4) COMO INICIAR LA NETWORK
----------------------------------------------------

1. Haz doble clic en:  START-NETWORK.bat
2. Se abrira el panel "AUREXMC NETWORK" con un menu.
3. Elige la opcion [1] Iniciar Network.
4. Se abriran 3 ventanas nuevas (Velocity, Lobby y
   Survival). Dejalas abiertas: son los servidores
   funcionando.
5. Cuando todo diga "Done" en su ventana, ya puedes
   conectarte.

No hace falta abrir nada mas a mano. Todo se controla
desde ese unico panel.

----------------------------------------------------
5) COMO DETENER LA NETWORK
----------------------------------------------------

Opcion recomendada (apagado correcto, guarda el mundo):
1. En el panel AUREXMC NETWORK, elige [3] Detener Network.

Opcion de emergencia (si cerraste el panel sin querer):
1. Haz doble clic en:  STOP-NETWORK.bat
   (Esto fuerza el cierre de los servidores que sigan
   abiertos. Usalo solo si la opcion [3] no esta disponible.)

----------------------------------------------------
6) COMO CONECTARSE DESDE MINECRAFT
----------------------------------------------------

Dentro de tu misma red local (mismo PC o misma WiFi/red):

  Direccion del servidor:  localhost:25565
  (o la IP local de tu PC, por ejemplo 192.168.1.50:25565,
   si te conectas desde otro dispositivo de tu casa)

Para jugar desde INTERNET (otras personas fuera de tu
casa) necesitarias además abrir el puerto 25565 en tu
router (port forwarding) y usar tu IP publica. Eso NO
lo hace este instalador por razones de seguridad: hazlo
solo si entiendes los riesgos.

El puerto que SIEMPRE debes usar para conectarte es:

  25565  (el de Velocity)

Nunca uses 25566 ni 25567 directamente: estan bloqueados
por fuera de tu PC a proposito.

----------------------------------------------------
7) QUE HACER SI APARECE UN ERROR
----------------------------------------------------

- "Java no encontrado" o version incorrecta:
  Reinstala Java 21 (Temurin) y prueba de nuevo con
  "java -version" en una ventana CMD.

- "No se pudo descargar Paper/Velocity":
  Revisa tu conexion a internet y vuelve a ejecutar
  INSTALL-AurexMC.bat. El instalador no crea archivos
  falsos si la descarga falla.

- Lobby o Survival no arrancan y piden la EULA:
  Sigue el paso 3 de este documento (aceptar la EULA).

- Un jugador no puede entrar y dice "puerto cerrado":
  Comprueba que iniciaste la Network desde el panel y
  que las 3 ventanas (Velocity, Lobby, Survival) dicen
  "Done".

- Quieres reinstalar desde cero:
  Cierra la network, borra las carpetas Velocity, Lobby
  y Survival, y vuelve a ejecutar INSTALL-AurexMC.bat.

- Cualquier otro error:
  Lee el mensaje que aparece en la ventana de PowerShell:
  esta escrito para ser entendible, e indica que archivo
  o paso fallo.

====================================================
  Disfruta tu network, AurexMC.
====================================================
