## Cuestionario 
###	1. ¿Qué es un proceso en Elixir? ¿Qué significa que los procesos tengan memoria aislada y cómo intercambian información?

Un proceso en Elixir es una unidad de ejecución liviana administrada por la máquina virtual de Erlang (Beam), no por el sistema operativo. Cada proceso tiene memoria aislada porque no puede leer variables ni modificar el estado de otro directamente, lo que evita condiciones de carrera (race condition). Los procesos se comunican por mensajes donde un proceso envía con "send" al pid del otro, y el mensaje queda en su mailbox (área de memoria que se utiliza para almacenar los mensajes recibidos, enviados por otros procesos). El receptor lo lee con "receive" haciendo pattern matching. El envío es asincrónico: el emisor no espera respuesta.

###	2. ¿Cuál es la diferencia entre concurrencia y paralelismo? ¿Puede haber concurrencia aunque sólo se disponga de un núcleo de procesamiento?

La concurrencia es cuando varias tareas progresan al mismo tiempo de forma lógica, sin necesariamente ejecutarse simultáneamente.  El paralelismo es cuando varias tareas se ejecutan exactamente al mismo tiempo, en distintos núcleos de procesamiento.

Sí, puede haber concurrencia con un solo núcleo. El procesador va alternando entre las tareas (por ejemplo, con un scheduler), dándoles pequeños tiempos de ejecución. Desde el punto de vista del programa, las tareas parecen avanzar juntas, pero en realidad se ejecutan de a una en cada instante. En Elixir, la BEAM maneja esta alternancia sin que el programador tenga que preocuparse.

### 3. ¿Qué es una condición de carrera (_race condition_)? ¿Por qué comprobar un dato y modificarlo en dos operaciones separadas puede producir resultados incorrectos cuando hay varios participantes?

Una condición de carrera (race condition) es cuando el resultado de un programa depende del orden en que se ejecutan varias operaciones concurrentes, y ese orden no está controlado. Si dos procesos acceden al mismo dato al mismo tiempo, el resultado puede variar entre ejecuciones.

El problema de comprobar y modificar en dos pasos es que entre la comprobación y la modificación otro proceso puede cambiar el dato. Por ejemplo, dos personas retiran efectivo de la misma cuenta al mismo tiempo. Cada operación hace dos pasos: primero comprueba el saldo, después resta el importe. Si el saldo es 100 y cada una retira 80, ambas leen 100, ambas comprueban que hay saldo suficiente, y ambas restan. El resultado queda en -60, cuando una de las dos debería haber sido rechazada. La comprobación queda desactualizada porque no es atómica: no ocurre junto con la modificación en un solo paso indivisible.

### 4. ¿Cómo ayuda que un único proceso administre un estado y atienda los pedidos de a uno a evitar condiciones de carrera? ¿Por qué usar procesos y mensajes no elimina automáticamente todos los problemas de concurrencia?

Un único proceso que administra el estado y atiende los pedidos de a uno evita condiciones de carrera porque no hay dos procesos modificando el estado al mismo tiempo: cada operación se resuelve completa antes de la siguiente.

Pero usar procesos y mensajes no elimina todos los problemas porque los mensajes llegan en orden arbitrario según quién los envíe, el orden de procesamiento puede variar entre ejecuciones, y siguen apareciendo problemas de sincronización como esperas, timeouts o mensajes tardíos. La concurrencia no desaparece, solo se traslada al manejo de mensajes.

### 5. ¿Qué garantías de orden ofrece Elixir para los mensajes enviados por un mismo proceso a otro? ¿Qué puede ocurrir cuando varios procesos envían mensajes al mismo destinatario?

Elixir garantiza que los mensajes enviados por un mismo proceso a otro llegan en el orden en que fueron enviados. Si el proceso A manda el mensaje 1 y después el mensaje 2 al proceso B, B los recibe en ese orden (primero 1, después 2). 

Pero cuando varios procesos envían mensajes al mismo destinatario, no hay garantía de orden entre ellos. Los mensajes de distintos emisores pueden llegar en cualquier orden, según cómo se planifiquen los procesos. El destinatario los va a recibir en el orden en que llegaron a su mailbox, pero ese orden puede variar entre distintas ejecuciones.

### 6. ¿Qué es el mailbox de un proceso y cómo selecciona mensajes un `receive`? ¿Qué ocurre con los mensajes que no coinciden con sus patrones?

El mailbox es el buzón de un proceso: una cola donde se acumulan los mensajes que recibe y que todavía no fueron procesados. Cuando un proceso recibe un mensaje con "send", ese mensaje queda guardado en su mailbox hasta que lo lea.

El "receive" recorre el mailbox y busca el primer mensaje que coincida con alguno de sus patrones. Si el primer mensaje no coincide, sigue con el siguiente, hasta encontrar uno que matchee. Cuando lo encuentra, lo saca del mailbox y ejecuta la acción correspondiente.

Los mensajes que no coinciden con ningún patrón se quedan en el mailbox. No se descartan: siguen ahí esperando a que un futuro "receive" los lea. Esto puede ser útil, pero también riesgoso, porque si nunca se leen se van acumulando y consumen memoria.

### 7. ¿Qué riesgos aparecen si un mailbox recibe mensajes más rápido de lo que el proceso puede atenderlos? Considerá el consumo de memoria, el tiempo de respuesta y el costo de buscar mensajes entre muchos pendientes. ¿Qué estrategias generales pueden reducir estos riesgos?

Si el mailbox recibe mensajes más rápido de lo que el proceso los atiende, se van acumulando. Eso tiene varios riesgos:
- Memoria: cada mensaje pendiente ocupa memoria. Si se acumulan muchos, el proceso puede consumir mucha memoria y eventualmente afectar a todo el sistema.
- Tiempo de respuesta: como el proceso atiende de a uno, los mensajes que están al final de la cola esperan cada vez más y genera que crezca la latencia.
- Costo de búsqueda: "receive" recorre el mailbox buscando un mensaje que coincida. Si hay muchos mensajes pendientes, esa búsqueda se vuelve más costosa, y el proceso tarda más en procesar cada mensaje.

Algunas estrategias para reducir estos riesgos son: limitar la cantidad de mensajes que se envían, usar varios procesos para repartir la carga, descartar mensajes que ya no sirven, o diseñar el sistema para que los productores no generen más rápido de lo que los consumidores pueden procesar.

### 8. ¿Qué indica un tiempo de espera agotado (_timeout_) al esperar una respuesta? ¿Por qué no implica necesariamente que la operación haya sido cancelada? ¿Qué problemas pueden generar las respuestas tardías y los reintentos?

Un timeout indica que el tiempo máximo de espera se agotó sin que llegara la respuesta. No significa que la operación haya fallado ni que se haya cancelado: solo que no llegó la respuesta a tiempo.

No implica cancelación porque el proceso que estaba haciendo la operación puede seguir ejecutándose. El timeout es solo del que espera, no del que procesa. La operación puede terminar después, y la respuesta llega tarde.

Las respuestas tardías pueden generar problemas: si el cliente ya asumió que falló y reintenta, puede terminar con dos operaciones realizadas cuando solo quería una. Los reintentos también pueden duplicar efectos si la operación original sí se había ejecutado. Para evitarlo se suelen usar identificadores únicos por pedido, para detectar duplicados.

### 9. ¿Qué significa que el envío de mensajes en Elixir sea asincrónico? ¿Qué diferencia hay entre enviar un mensaje, que el destinatario lo reciba y que termine de procesarlo?

Que el envío sea asincrónico significa que "send" no bloquea al emisor: el proceso que envía sigue ejecutándose inmediatamente después, sin esperar a que el destinatario reciba o procese el mensaje.

Hay tres momentos distintos: enviar el mensaje (el emisor lo pone en el mailbox del destinatario y sigue), que el destinatario lo reciba (el mensaje ya está en su mailbox pero puede no haberlo leído todavía) y que termine de procesarlo (el destinatario lo leyó con "receive" y ejecutó la acción correspondiente). Estos momentos no coinciden: entre el envío y el procesamiento puede pasar tiempo, y el emisor no tiene forma de saber cuándo ocurre salvo que el destinatario le responda con otro mensaje.

### 10. ¿Qué ocurre con el estado y los mensajes pendientes de un proceso cuando termina? ¿Cómo puede otro proceso enterarse de su terminación y por qué sería útil conocerla?

Cuando un proceso termina, su estado y los mensajes pendientes en su mailbox se pierden. Como la memoria es aislada, nadie más puede acceder a esos datos: desaparecen con el proceso. Los mensajes que habían llegado y no fueron procesados se descartan.

Otro proceso puede enterarse de la terminación usando *Process.monitor/1*, que devuelve una referencia. Cuando el proceso monitoreado muere, el que lo monitorea recibe un mensaje con la razón. También existe *Process.link/1*, que hace que si un proceso muere, el otro reciba una señal de salida.

Conocer la terminación es útil para detectar fallos, liberar recursos, reintentar operaciones, actualizar el estado de otros procesos o evitar quedarse esperando una respuesta que nunca va a llegar.