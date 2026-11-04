# Casa de Subastas

Trabajo Práctico 1 

- **Nombre:** César Castellanos
- **Padrón:** 81404
- **Elixir:** 1.19.2
- **Erlang/OTP:** 26

## Requisitos

- Elixir 1.19 o superior
- Erlang/OTP 26 o superior
- Mix (incluido con Elixir)

## Instalación y compilación

    git clone https://github.com/castellanoscesar/casa_subasta.git
    cd casa_subasta
    mix compile

## Ejecutar la CLI

    iex -S mix

Dentro de IEx:

    CliCasaSubasta.run()

### Comandos disponibles

| Comando | Descripción |
|---|---|
| `crear "Producto" precio duracion_ms` | Crea una subasta |
| `activas` | Lista subastas activas |
| `consultar id` | Muestra el estado de una subasta |
| `ofertar id usuario importe` | Realiza una oferta |
| `ayuda` | Muestra los comandos |
| `salir` | Termina la aplicación |

### Ejemplo de uso

    > crear "Teclado" 1000 30000
    OK subasta=1 producto="Teclado" precio_inicial=1000 duracion_ms=30000

    > activas
    1 | Teclado | sin ofertas

    > ofertar 1 ana 1200
    OK oferta_aceptada subasta=1 usuario=ana importe=1200

    > ofertar 1 bruno 1200
    ERROR offer_too_low subasta=1

    > ofertar 1 bruno 1500
    OK oferta_aceptada subasta=1 usuario=bruno importe=1500

    > consultar 1
    subasta=1 producto="Teclado" estado=active precio_inicial=1000
    ofertas_aceptadas=2 mayor_oferta=1500 usuario=bruno

Tras el vencimiento:

    > consultar 1
    subasta=1 producto="Teclado" estado=closed precio_inicial=1000
    ofertas_aceptadas=2 ganador=bruno precio_final=1500

## Ejecutar tests

    mix test

## Ejecutar simulación de 100 usuarios

    mix run scripts/SimulacionSubastas.exs

Con semilla fija para reproducir datos:

    mix run scripts/SimulacionSubastas.exs 12345

La simulación crea 3 subastas, lanza 100 procesos usuario que consultan y ofertan concurrentemente (incluyendo ofertas iguales, insuficientes y post-vencimiento), espera el cierre automático y verifica que los resultados coincidan con las ofertas aceptadas.

## Diseño

### Procesos

| Proceso | Responsabilidad |
|---|---|
| `AuctionCoordinator` | Asigna ids únicos, mantiene mapa de subastas y atiende creación, búsqueda y listado |
| `AuctionServer` | Un proceso por subasta. Mantiene el estado de la subasta, atiende ofertas y consultas, y cierra automáticamente al vencer |
| Procesos cliente | Usuarios de la CLI o simulación que envían mensajes y esperan respuesta |

### Decisiones de diseño

- **Un proceso por subasta**: cada subasta tiene su propio AuctionServer con estado aislado. Esto garantiza independencia entre subastas y evita que una operación en una subasta afecte a otra.
- **Ofertas en lista**: las ofertas se guardan en una lista (no en un mapa) porque el orden de procesamiento importa para resolver empates. La oferta más reciente se agrega al principio con [offer | offers].
- **Mensajes con caller**: cada pedido incluye el pid del solicitante para enviar una respuesta única. Esto garantiza que cada solicitud reciba una sola respuesta identificable.
- **Coordinador central**: actúa como registro que asigna ids únicos y permite localizar subastas por id. No mantiene el estado de las subastas, solo los pids.

### Vencimiento

Cada AuctionServer lanza un proceso temporizador al iniciarse que duerme duration milisegundos y envía :close al servidor. Además, tanto Auction.start/3 como la consulta de estado verifican el deadline contra System.system_time(:millisecond) para rechazar ofertas y mostrar la subasta cerrada incluso si el temporizador aún no procesó el cierre.

### Resolución de ofertas concurrentes

Cada subasta es administrada por un único proceso que atiende los mensajes de a uno. Esto garantiza que las ofertas se procesen en orden secuencial: la referencia vigente (precio inicial o mayor oferta aceptada) se compara contra cada nueva oferta antes de aceptarla. Si dos ofertas iguales llegan concurrentemente, solo la primera procesada es aceptada.

## Limitaciones conocidas

- El estado se mantiene en memoria; no hay persistencia.
- El cierre automático depende de la planificación del temporizador; no se garantiza precisión de milisegundos.