
#						 Snake                                             
#==================================================================================================
#
# Para el uso de este programa se requiere conectar las siguientes herramientas de MARS 4.5:	   
#												   
# -Keyboard and Display MMIO Simulator								   
# -Bitmap Display										   
# 												   
# Configuración de Bitmap Display:								   
#												   
#	Unit Width: 8						   				   
#	Unit Height: 8								                   
#	Display Width: 512							                   
#	Display Height: 512					   				   
#	Base Address for Display: 0x10010000(static data)						   
#		
# Después de configurar el Bitmap Display, presionar el botón Connect to MIPS en ambas herramientas, compilar e iniciar el programa
#									   
#	Programador: Adolfo Ovalle								   

.data
# Se reserva un arreglo de memoria para almacenar el display
display : .word 0:262144 		#512x512

# Se reserva un arreglo de memoria del mismo tamaño que el display para almacenar los cambios de dirección de la serpiente 
# en su posición correspondiente, y poder usarlos como direcciones nuevas para la cola
cambios : .word 0:262144 		#512x512

# Se reserva espacio para un arreglo que contiene 5 elementos
# [0] Posición en X de la cabeza, 
# [1] Posición en Y de la cabeza, 
# [2] Contador de unidades del puntaje (score), 
# [3] Contador de decenas de puntaje, 
# [4] Valor binario que indica si se debe actualizar el score en el display (0 o 1)
# Tablero abstracto de 64x56 unidades espaciales (pixeles) (desde 0-63 y 0-55)
# (32, 16) posición inicial de la cabeza
status: .word 32, 16, 0, 0, 0 			#x,y,unidad,decena,actualizar?

# Se reserva espacio para un elemento que indica la dirección de la cola equivalente al valor de la tecla minúscula presionada
# para moverse en tal dirección, inicialmente es hacia arriba 
direccionCola: .word 119
# Se reserva espacio para un elemento que indica la posición de la cola en el tablero, en coordenadas X, Y
# (32, 16) posición inicial de la cola
localizacionCola: .word 32, 16

# Se reservan y definen los strings que se utilizan para pedir al usuario ingresar la seed 
MensajeSeed:	.asciiz "Ingrese seed deseada (cualquier entero)"
MensajeError:	.asciiz "Ha ingresado un valor incorrecto, o no ha ingresado nada, vuelva a intentarlo" 


.text

#Se especifican los argumentos y salidas de cada función de la siguiente forma:
#
# NOTA: se utiliza - para simbolizar que no recibe o retorna argumentos
#================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------
# Nombre de la función (label) / Argumentos de la función (si recibe) / Valor que retorna la función (si retorna)
# Descripción
#================================================================================================================================


#================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------
# Start / - / - 
# Función que inicia un nuevo juego, inicializando los registros y conteniendo en Main el juego en ejecución
#================================================================================================================================

Start:
		jal reset # Llamada a la función reset para inicializar los registros
		jal printCero # Inicializa el score con un 0
		
#================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------
# SetSeed / Input de usuario / Si el input es correcto, se almacenará en $a0
# Se usa la syscall 51 para pedir al usuario que ingrese la seed que desee. Utiliza el método "incorrecto" para indicar al usuario
# si necesita volver a ingresarla
#================================================================================================================================
	
	setSeed:
		li $v0, 51
		la $a0, MensajeSeed 
		syscall
		beq $a1, 0, correcto		
		beq $a1, -1, incorrecto
		beq $a1, -2, exit
		beq $a1, -3, incorrecto

	incorrecto:
		li $v0, 51 
		la $a0, MensajeError 
		syscall
		beq $a1, 0, correcto
		beq $a1, -1, incorrecto
		beq $a1, -2, exit
		beq $a1, -3, incorrecto

#================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------
# correcto/ $a0: seed seleccionada por el usuario / -
# Establece la seed para el generador aleatorio con la syscall 40, en base a la ingresada por el usuario en setSeed o incorrecto
#================================================================================================================================

	correcto:
		move $a1, $a0
		li $a0, 0
		li $v0, 40
		syscall
	
	# Ciclo que realiza una cantidad (50 default) de llamadas a la función que genera obstáculos 
	forObstaculos: 
		beq $t8, 50, comida	# $t8 es un contador global de obstáculos en el mapa
		jal randomOb
	j forObstaculos
	
	comida:
		jal randomCo # Se genera la primera comida del mapa
	
#================================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------
# Main/ status[4]: (5to elemento de status) 1 si debe actualizar el score, 0 si no / -
# Ciclo principal que contiene el juego en ejecución, chequea constantemente el input del usuario y decide que se debe hacer a partir de este
#================================================================================================================================================
	Main:
		la $t6, status             	# Cargar dirección de memoria de status
		lw $s0, 16($t6)		  	# Accede al 5to elemento almacenandolo en s0
		beq $s0, 1, actualizar	   	# Si es 1, significa que hubo cambios en el puntaje, 
						# por lo que se llama a actualizar el score del display
		cc:
		sw $zero, 16($t6)	   	# Reinicialización del valor de cambio
		
		la $a0, 0xffff0004		# Direccion donde se aloja el valor del teclado
		lw $a0, 0($a0)			# a0 = valor del teclado
		
		# Minúsculas
		beq $a0, 113, exit 		# q llamada para salir del juego
		beq $a0, 97, moverIzq 		# a izquierda : llamada para mover la serpiente hacia la izquierda
		beq $a0, 100, moverDer 		# d derecha : llamada para mover la serpiente hacia la derecha
		beq $a0, 115, moverDown 	# s abajo : llamada para mover la serpiente hacia abajo
		beq $a0, 119, moverUp 		# w arriba : llamada para mover la serpiente hacia arriba
		
		# Mayúsculas
		beq $a0, 81, exit 		# Q llamada para salir del juego
		beq $a0, 65, moverIzq 		# A izquierda : llamada para mover la serpiente hacia la izquierda
		beq $a0, 68, moverDer 		# D derecha : llamada para mover la serpiente hacia la derecha
		beq $a0, 83, moverDown 		# S abajo : llamada para mover la serpiente hacia abajo
		beq $a0, 87, moverUp 		# W arriba : llamada para mover la serpiente hacia arriba
		
		sigue:
		
		# Pausar la ejecución: 
		li $a0, 150 			# a0 = 150
		li $v0, 32			# Valor syscall 32 para realizar una espera del largo del valor de a0 en milisegundos 
						# (esto se utiliza para esperar el input del usuario)
		syscall				# Ejecutar el syscall
		
	j Main



#=============================================================================================
#--------------------------MOVIMIENTOS--------------------------------------------------------
#=============================================================================================		
		
#========================================================================================================================
# Función / Entrada / Salida
#------------------------------------------------------------------------------------------------------------------------
# moverIzq / $t7 contiene display / $t5 = 97 (indica la dirección actual de la serpiente, en este caso 97 es izquierda)
# Función que mueve la serpiente una unidad hacia la izquierda
#========================================================================================================================			
moverIzq:

	# Si la dirección anterior de la serpiente era la contraria, entonces no se realiza esta función y se redirige hacia
	# el movimiento que la serpiente llevaba, ya que la serpiente no puede retroceder sobre si misma
	beq $t5, 100, mDe 		
	
	mI:
	# Se guarda la dirección actual en t5 y en a0 (por si se llega redirigido a esta función)
	li $a0, 97			
	li $t5, 97	
	# Se guarda en el arreglo cambios el cambio de dirección realizado		
	jal cambioDireccion 		
	# Cargar dirección de memoria de status
	la $t6, status        
	# Se carga el primer elemento (posición en X) en s0      	
	lw $s0, 0($t6)	
	# Si se alcanzó X=0, entonces se debe aparecer por el otro lado de la pantalla		
	beqz $s0, izqX			
	
	# Posición de la cabeza en X = X - 1
	addi $s0, $s0, -1		
	sw $s0, 0($t6)			
	
	# Posición de la cabeza en el display se mueve una unidad hacia la izquierda
	addi $t7, $t7, -4
	#Chequeo de colisiones en la nueva localización del display
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración
	lw $s0, 16($t6)
	beq $s0, 1, avanza	
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección
	jal borrarCola
	jal moverCola
	jal chequearCambios


j avanza

		
#==============================================================================================================================
# Función / Entrada / Salida
#------------------------------------------------------------------------------------------------------------------------------
# moverDer / $t7 contiene display / $t5 = 100 (indica la dirección actual de la serpiente, en este caso 100 es derecha)
# Función que mueve la serpiente una unidad hacia la derecha
#==============================================================================================================================	

moverDer:

	# Si la dirección anterior de la serpiente era la contraria, entonces no se realiza esta función y se redirige hacia el movimiento 
	# que la serpiente llevaba, ya que la serpiente no puede retroceder sobre si misma
	beq $t5, 97, mI		
		
	mDe:
	# Se guarda la dirección actual en t5 y en a0 (por si se llega redirigido a esta función)
	li $a0, 100			
	li $t5, 100		
		
	# Se guarda en el arreglo cambios el cambio de dirección realizado
	jal cambioDireccion 	
		
	# Cargar dirección de memoria de status
	la $t6, status    
	          	
	# Se carga el primer elemento (posición en X) en s0
	lw $s0, 0($t6)		
		
	# Si se alcanzó X=63, entonces se debe aparecer por el otro lado de la pantalla
	beq $s0, 63, derX		
	
	# Posición de la cabeza en X = X + 1
	addi $s0, $s0, 1
	sw $s0, 0($t6)
	
	# Posición de la cabeza en el display se mueve una unidad hacia la derecha	
	addi $t7, $t7, 4
	
	#Chequeo de colisiones en la nueva localización del display
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca, 
	# se salta el borrar la cola por esta iteración	
	lw $s0, 16($t6)
	beq $s0, 1, avanza
		
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección	
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

		
#==============================================================================================================================
# Función / Entrada / Salida
#------------------------------------------------------------------------------------------------------------------------------
# moverDown / $t7 contiene display / $t5 = 119 (indica la dirección actual de la serpiente, en este caso 119 es abajo)
# Función que mueve la serpiente una unidad hacia abajo
#==============================================================================================================================	

moverDown:

	# Si la dirección anterior de la serpiente era la contraria, entonces no se realiza esta función y se redirige 
	# hacia el movimiento que la serpiente llevaba, ya que la serpiente no puede retroceder sobre si misma
	beq $t5, 119, mU
	
	mD:
	# Se guarda la dirección actual en t5 y en a0 (por si se llega redirigido a esta función)
	li $a0, 115			
	li $t5, 115	
		
	# Se guarda en el arreglo cambios el cambio de dirección realizado		 
	jal cambioDireccion 	
		
	# Cargar dirección de memoria de status
	la $t6, status              	
	
	# Se carga el segundo elemento (posición en Y) en s0
	lw $s0, 4($t6)			
	
	# Si se alcanzó Y=55, entonces se debe aparecer por el otro lado de la pantalla
	beq $s0, 55, downY		
	
	# Posición de la cabeza en Y = Y + 1	
	addi $s0, $s0, 1
	sw $s0, 4($t6)
	
	# Posición de la cabeza en el display se mueve una unidad hacia la derecha	
	addi $t7, $t7, 256
	#Chequeo de colisiones en la nueva localización del display	
	jal colision

	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca, 
	# se salta el borrar la cola por esta iteración	
	lw $s0, 16($t6)
	beq $s0, 1, avanza
	
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección		
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

		
#======================================================================================================================
# Función / Entrada / Salida
#----------------------------------------------------------------------------------------------------------------------
# moverUp / $t7 contiene display / $t5 = 115 (indica la dirección actual de la serpiente, en este caso 115 es arriba)
# Función que mueve la serpiente una unidad hacia arriba
#======================================================================================================================	

moverUp:

	# Si la dirección anterior de la serpiente era la contraria, entonces no se realiza esta función y se redirige 
	# hacia el movimiento que la serpiente llevaba, ya que la serpiente no puede retroceder sobre si misma
	beq $t5, 115, mD
	
	mU:
	# Se guarda la dirección actual en t5 y en a0 (por si se llega redirigido a esta función)
	li $a0, 119
	li $t5, 119
	
	# Se guarda en el arreglo cambios el cambio de dirección realizado	 
	jal cambioDireccion 
	
	# Cargar dirección de memoria de status
	la $t6, status   
	
	# Se carga el segundo elemento (posición en Y) en s0          
	lw $s0, 4($t6)
	
	# Si se alcanzó Y=55, entonces se debe aparecer por el otro lado de la pantalla	
	beqz $s0, upY
	
	# Posición de la cabeza en Y = Y - 1		
	addi $s0, $s0, -1
	sw $s0, 4($t6)
	
	# Posición de la cabeza en el display se mueve una unidad hacia la derecha		
	addi $t7, $t7, -256
	#Chequeo de colisiones en la nueva localización del display		
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración	
	lw $s0, 16($t6)
	beq $s0, 1, avanza
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección	
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

#====================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------
# avanza / $t7 contiene display / almacena el valor 0x00ff00 (color verde) en la posición actual del display
# Se pinta la nueva posición de la cabeza en el display
#====================================================================================================================

avanza:
	addi $t2 , $zero , 0x00ff00 #VERDE
	sw $t2 , 0($t7)
j sigue

#=============================================================================================
#------------------------------------COMPROBAR COLISIONES -----------------------------------
#=============================================================================================
#======================================================================================================================
# Función / Entrada / Salida
#----------------------------------------------------------------------------------------------------------------------
# colision / $t7 contiene display / -
# Chequea según el color contenido en la dirección actual del display, si se debe terminar la partida o sumar puntaje
#======================================================================================================================

colision:
	lw $t2, 0($t7)
	beq $t2, 0xCCCCFF, gameover		#Si es obstáculo
	beq $t2, 0x00ff00, gameover		#Si es el cuerpo de la serpiente
	beq $t2, 0xFF6600, sumarpuntaje		#Si es una comida
jr $ra

#=============================================================================================
#------------------------------------SALTOS DE ESPACIO --------------------------------------
#=============================================================================================
#=============================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------
# izqX / $t7 contiene display, $t6 contiene status / -
# Mueve a la serpiente desde el borde izquierdo de la pantalla al borde derecho
#=============================================================================================

izqX:
	# Le suma 63 a la posición de la cabeza en X
	addi $s0, $s0, 63
	sw $s0, 0($t6)
	
	#Setea la nueva posición en el arreglo display y chequea por colisiones
	addi $t7, $t7, 252
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración
	lw $s0, 16($t6)
	beq $s0, 1, avanza
	
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección		
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

#=====================================================================================
# Función / Entrada / Salida
#-------------------------------------------------------------------------------------
# derX / $t7 contiene display, $t6 contiene status / -
# Mueve a la serpiente desde el borde derecho de la pantalla al borde izquierdo
#=====================================================================================

derX:
	# Le resta 63 a la posición de la cabeza en X
	addi $s0, $s0, -63
	sw $s0, 0($t6)
	
	#Setea la nueva posición en el arreglo display y chequea por colisiones
	addi $t7, $t7, -252
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración	
	lw $s0, 16($t6)
	beq $s0, 1, avanza
	
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección		
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

#=====================================================================================
# Función / Entrada / Salida
#-------------------------------------------------------------------------------------
# downY / $t7 contiene display, $t6 contiene status / -
# Mueve a la serpiente desde el borde inferior de la pantalla al borde superior
#=====================================================================================

downY:
	# Le resta 55 a la posición de la cabeza en Y
	addi $s0, $s0, -55
	sw $s0, 4($t6)
	
	#Setea la nueva posición en el arreglo display y chequea por colisiones	
	addi $t7, $t7, -14080
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración		
	lw $s0, 16($t6)
	beq $s0, 1, avanza
	
	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección			
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

#=============================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------
# upY / $t7 contiene display, $t6 contiene status / -
# Mueve a la serpiente desde el borde superior de la pantalla al borde inferior
#=============================================================================================

upY:
	# Le suma 55 a la posición de la cabeza en Y
	addi $s0, $s0, 55
	sw $s0, 4($t6)
	
	#Setea la nueva posición en el arreglo display			
	addi $t7, $t7, 14080
	jal colision
	
	# Si el quinto valor del arreglo status es 1, significa que se encontró una comida, por lo que para que la serpiente crezca,
	# se salta el borrar la cola por esta iteración			
	lw $s0, 16($t6)
	beq $s0, 1, avanza

	# Se borra la cola (su último pixel) y se determina la nueva localización y su dirección			
	jal borrarCola
	jal moverCola
	jal chequearCambios

j avanza

#===============================================================================================
#-----------------------MOVIMIENTO DE COLA------------------------------------------------------
#===============================================================================================
#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# cambioDireccion / $a0 = última dirección de la cabeza / -
# Se obtiene la localización actual de la cabeza en el display, y se almacena en la misma posición del arreglo "cambios" la dirección que la cabeza tomó
#=========================================================================================================================================================

cambioDireccion:


	la $t6, status 		# se carga la memoria de status
	lw $s0, 0($t6)		# se obtienen las posiciones X e Y de la cabeza
	lw $t2, 4($t6)		# $s0 = X, $t2 = Y
	mul $t2, $t2, 256	# $t2 = Y*256
	mul $s0, $s0, 4		# $s0 = X*4
	add $t2, $t2, $s0	# $t2 = Y*256 + X*4

	la $t6, cambios		# $t6 = arreglo cambios
	add $t6, $t6, $t2	# $t6 = cambios+$t2 = direccion en memoria de "cambios" equivalente a la posición actual de la cabeza
	sw $a0, 0($t6)		# se guarda la dirección que tomó la cabeza en esta posición en el arreglo cambios

jr $ra

#====================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------
# moverCola / - / -
# Se revisa la dirección de la cola, y según esta se procede a mover la cola un espacio en esa dirección
#====================================================================================================================

moverCola:

	la $t6, direccionCola		# se carga la dirección donde se encuentra la dirección actual de la cola
	lw $s0, 0($t6)			# $s0 = dirección actual de la cola
	beq $s0, 97, colaIzq 		# a izquierda
	beq $s0, 100, colaDer 		# d derecha
	beq $s0, 115, colaDown 		# s abajo
	beq $s0, 119, colaUp 		# w arriba
	colaOut:
	
jr $ra	

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaUp / - / -
# Después que se ha enviado la orden de moverse hacia arriba a la cola, se procede a chequear como se debe actuar dependiendo su localización en Y
#=========================================================================================================================================================

colaUp:	

	la $t6, localizacionCola 	# carga la memoria donde se encuentra la localizacion de la cola
	lw $t2, 4($t6)			# $t2 = posición en Y de la cola
	beqz $t2, colaUpY		# si la posición de la cola en Y es 0, significa que debe aparecer en el otro extremo del display 
	addi $t2, $t2, -1		# si no es 0, entonces Y = Y-1
	sw $t2, 4($t6)			# se guarda la nueva coordenada de la cola en Y
	
j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaUpY / $t2 contiene posición en Y de la cola, $t6 contiene la direccion de memoria donde se almacena la posición de la cola / -
# Se mueve la cola de la serpiente al extremo inferior de la pantalla despues de haber sido movida desde el extremo superior hacia arriba
#=========================================================================================================================================================

colaUpY:

	addi $t2, $t2, 55		# Y = Y + 55 (Y es 0 inicialmente)
	sw $t2, 4($t6)			# se guarda la nueva coordenada en Y de la cola
	
j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaDer / - / -
# Después que se ha enviado la orden de moverse hacia la derecha a la cola, se procede a chequear como se debe actuar dependiendo su localización en X
#=========================================================================================================================================================

colaDer:
	
	la $t6, localizacionCola 	# carga la memoria donde se encuentra la localizacion de la cola
	lw $t2, 0($t6)			# $t2 = posición en X de la cola
	beq $t2, 63, colaDerX		# si la posición de la cola en X es 63, significa que debe aparecer en el otro extremo del display 
	addi $t2, $t2, 1		# si no es 63, entonces X = X + 1
	sw $t2, 0($t6)			# se guarda la nueva posición de la cola en X

j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaDerX / $t6 contiene la dirección donde se almacena la posición la cola / -
# Se mueve la cola de la serpiente al extremo izquierdo de la pantalla despues de haber sido movida desde el extremo derecho hacia la derecha
#=========================================================================================================================================================

colaDerX:
	
	li $t2, 0			# $t2 = 0
	sw $t2, 0($t6)			# se guarda la nueva coordenada 0 en X de la cola

j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaIzq / - / -
# Después que se ha enviado la orden de moverse hacia la izquierda a la cola, se procede a chequear como se debe actuar dependiendo su localización en X
#=========================================================================================================================================================

colaIzq:
	
	la $t6, localizacionCola	# carga la memoria donde se encuentra la localizacion de la cola
	lw $t2, 0($t6)			# $t2 = posición en X de la cola
	beqz $t2, colaIzqX		# si la posición de la cola en X es 0, significa que debe aparecer en el otro extremo del display 
	addi $t2, $t2, -1		# si no es 0, entonces X = X - 1
	sw $t2, 0($t6)			# se guarda la nueva posición de la cola en X
	
j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaIzqX / $t6 contiene la dirección donde se almacena la posición la cola, $t2 = 0 (posición en coordenada X de la cola) / -
# Se mueve la cola de la serpiente al extremo derecho de la pantalla despues de haber sido movida desde el extremo izquierdo hacia la izquierda
#=========================================================================================================================================================

colaIzqX:

	addi $t2, $t2, 63		# $t2 = 63 (es inicialmente 0)
	sw $t2, 0($t6)			# se guarda la nueva coordenada 63 en X de la cola
	
j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaDown / - / -
# Después que se ha enviado la orden de moverse hacia abajo a la cola, se procede a chequear como se debe actuar dependiendo su localización en Y
#=========================================================================================================================================================

colaDown:
	
	la $t6, localizacionCola	# carga la memoria donde se encuentra la localizacion de la cola
	lw $t2, 4($t6)			# $t2 = posición en Y de la cola
	beq $t2, 55, colaDownY		# si la posición de la cola en Y es 55, significa que debe aparecer en el otro extremo del display 
	addi $t2, $t2, 1		# si no es 55, entonces Y = Y + 1
	sw $t2, 4($t6)			# se guarda la nueva posición de la cola en Y
	
j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# colaIzqX / $t6 contiene la dirección donde se almacena la posición la cola, $t2 = 0 (posición en coordenada X de la cola) / -
# Se mueve la cola de la serpiente al extremo derecho de la pantalla despues de haber sido movida desde el extremo izquierdo hacia la izquierda
#=========================================================================================================================================================

colaDownY:

	li $t2, 0		# $t2 = 0 
	sw $t2, 4($t6)		# se guarda la nueva coordenada 0 en Y de la cola

j colaOut

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# chequearCambios / - / -
# Se revisa si hubo cambios en la dirección de la serpiente en la localización actual de la cola, para cambiar su dirección si se encuentran
#=========================================================================================================================================================

chequearCambios:

	la $t6, localizacionCola		# se carga la memoria donde se ubica la localizacion de la cola
	lw $s0, 0($t6)				# se obtienen las posiciones X e Y de la cabeza
	lw $t2, 4($t6)				# $s0 = X, $t2 = Y
	mul $t2, $t2, 256			# $t2 = Y*256
	mul $s0, $s0, 4				# $s0 = X*4
	add $t2, $t2, $s0			# $t2 = Y*256 + X*4 (dirección de la cola en el arreglo display)

	la $t6, cambios 		# carga el inicio del arreglo donde se almacenan los cambios de direccion
	add $t6, $t6, $t2 		# le suma la direccion real de la cola
	lw $a0, 0($t6) 			# carga el valor almacenado en esa direccion
	bgtz $a0, cambiarDireccion 	# chequea si hay cambios detectados en la direccion correspondiente

jr $ra

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# cambiarDireccion / $a0 contiene el elemento actual del arreglo "cambios", $t6 contiene direccion de arreglo "cambios"  / -
# Reinicia el elemento actual del arreglo de memoria "cambios" asignandole un 0, y asigna el valor que tenía a la dirección actual de la cola
#=========================================================================================================================================================

cambiarDireccion:

	sw $zero, 0($t6) 		# se asigna un 0 al elemento actual de "cambios", dado que se su informacion ya se salvó en $a0
	la $t6, direccionCola		# se carga la dirección donde se encuentra la dirección actual de la cola
	sw $a0, 0($t6)			# se cambia la dirección de la cola asignandole la anteriormente contenida en la posición actual de "cambios",
					# esta posición coincide con la posición de la cola en el display

jr $ra


#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# borrarCola / -  / -
# Borra el último pixel de la serpiente ( la cola )
#=========================================================================================================================================================

borrarCola:

	la $t6, localizacionCola		# se carga la memoria donde se ubica la localizacion de la cola
	lw $s0, 0($t6)				# se obtienen las posiciones X e Y de la cabeza
	lw $t2, 4($t6)				# $s0 = X, $t2 = Y
	mul $t2, $t2, 256			# $t2 = Y*256
	mul $s0, $s0, 4				# $s0 = X*4
	add $t2, $t2, $s0			# $t2 = Y*256 + X*4 (dirección de la cola en el arreglo display)

	la $t6, display				# se carga la dirección de memoria del display 
	add $t6, $t6, $t2			# se le suma la posición de la cola en el arreglo, calculada anteriormente en $t2
	addi $t2 , $zero , 0x000000 #NEGRO	# se asigna el color negro
	sw $t2 , 0($t6)				# se pinta la cola de color negro, "borrandola" del display

jr $ra

#===============================================================================================
#-----------------------ACTUALIZACION DE SCORE--------------------------------------------
#===============================================================================================
#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# restartScore / $t6 = status  / decenas de score = 0
# Se asigna al entero de decenas de score en el arreglo status, el valor 0, esto sucede cuando se alcanzan los 100 de puntaje, convirtiendose en 0
#=========================================================================================================================================================

restartScore:

	li $s0, 0		# $s0 = 0
	sw $s0, 12($t6)		# decenas de score = 0

j cc

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# sumarpuntaje / - / estado de actualización = 1
# Se suma 1 al número de unidades en la dirección del arreglo status que contiene el puntaje, luego se setea el estado de actualización en 1
#=========================================================================================================================================================

sumarpuntaje:

	la $t6, status              	# Cargar dirección de memoria de status
	lw $s0, 8($t6)			# $s0 = unidades de score
	addi $s0, $s0, 1		# $s0 = $s0 + 1
	sw $s0, 8($t6)			# unidades de score ++
	
	li $a0, 1			# $a0 = 1
	sw $a0, 16($t6)			# estado de actualización = 1 (indica que se realizaron cambios al puntaje)

jr $ra

#=========================================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------------------
# actualizar / $t6 = status / -
# Se imprime una nueva comida y luego se limpia y se imprime el nuevo puntaje en el display
#=========================================================================================================================================================

actualizar:
	
	jal randomCo			# Genera una nueva comida
	la $t6, status              	# Cargar dirección de memoria de status
	lw $s0, 8($t6)			# $s0 = número de unidades (score)
	
	# Se limpian los marcadores y luego se imprime el dígito de unidad correspondiente a $s0
	jal ClearScore
	beq $s0, 0, cero
	beq $s0, 1, uno
	beq $s0, 2, dos
	beq $s0, 3, tres
	beq $s0, 4, cuatro
	beq $s0, 5, cinco
	beq $s0, 6, seis
	beq $s0, 7, siete
	beq $s0, 8, ocho
	beq $s0, 9, nueve
	beq $s0, 10, diez
	sc:
	
	lw $s0, 12($t6) # $s0 = número de decenas (score)
	
	# se imprime el dígito de decena correspondiente a $s0
	beq $s0, 1, printDUno
	beq $s0, 2, printDDos
	beq $s0, 3, printDTres
	beq $s0, 4, printDCuatro
	beq $s0, 5, printDCinco
	beq $s0, 6, printDSeis
	beq $s0, 7, printDSiete
	beq $s0, 8, printDOcho
	beq $s0, 9, printDNueve

j cc

#=======================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------
# diez / $t6 = status / -
# Cuando se alcanzan 10 unidades de puntaje se llama a esta función que vuelve a 0 las unidades y suma 1 a las decenas del contador, 
# luego imprimiendo o reiniciando según sea el caso
#=======================================================================================================================================

diez:
	li $s0, 0			# $s0 = 0
	sw $s0, 8($t6)			# score unidades = 0
	lw $s0, 12($t6)			# carga score decenas
	addi $s0, $s0, 1		# decenas = decenas + 1
	sw $s0, 12($t6)			
	jal ClearScore			# limpiar score
	jal printCero			# imprime 0 en el dígito de unidades
	
	# Según el número actual de decenas del score, imprime el número actual, o si es 10 se reinicia el score completo
	# para que para que inicie de 0 nuevamente
	beq $s0, 10, restartScore
	beq $s0, 1, printDUno
	beq $s0, 2, printDDos
	beq $s0, 3, printDTres
	beq $s0, 4, printDCuatro
	beq $s0, 5, printDCinco
	beq $s0, 6, printDSeis
	beq $s0, 7, printDSiete
	beq $s0, 8, printDOcho
	beq $s0, 9, printDNueve

j cc

#==============================================================================================================================
# Función / Entrada / Salida
#------------------------------------------------------------------------------------------------------------------------------
# "número" / - / -
# Funciones de encapsulamiento que imprimen el número que llevan de label, y luego se devuelven al ciclo Main del juego o 
# a la segunda parte de la función actualizar para imprimir el dígito de decena
#==============================================================================================================================


cero:
	jal printCero
j cc


uno:
	jal printUno
j sc


dos:
	jal printDos
j sc


tres:
	jal printTres
j sc


cuatro:
	jal printCuatro
j sc


cinco:
	jal printCinco
j sc


seis:
	jal printSeis
j sc


siete:
	jal printSiete
j sc


ocho:
	jal printOcho
j sc


nueve:
	jal printNueve
j sc


#===============================================================================================
#-------------------------GENERADOR DE OBSTÁCULOS---------------------------------------------
#===============================================================================================
#=============================================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------------------------
# randomOb / $t8 = contador de obstáculos / -
# Genera una posición pseudo aleatoria dependiente del seed seteado, y dibuja un obstáculo en esa posición
#=============================================================================================================================================

randomOb:
	li $a0, 0		# Número para el generador pseudo aleatorio (es 0 porque cuando se setea la seed se hace para este número)
	li $a1, 3584		# Límite máximo de número generado
	li $v0, 42		# syscall 42 (obtiene número pseudo aleatorio en $a0)
	syscall	

	la $t1 , display			# $t1 = display
	move $t4, $a0 				# $t4 = número pseudo aleatorio generado
	sll $t4, $t4, 2				# se multiplica por 4 para que calze con la dirección de display
	add $t1, $t4, $t1			# se le suma al lugar de inicio del arreglo de display para pintarlo
	addi $t3 , $zero , 0xCCCCFF 		# $t3 = color 0xCCCCFF
	
	# se obtiene el color actual de la dirección deseada para pintar, si es un jugador o un obstáculo se vuelve a generar otro número
	lw $t4, 0($t1)
	beq $t4, 0x00ff00, randomOb
	beq $t4, 0xCCCCFF, randomOb
	# para lograr que todo el mapa sea accesible para el jugador, se revisan tambien todos los espacios adyacentes al actual
	# así nunca habrán dos obstáculos juntos, y por consiguiente siempre habrá un espacio por donde el jugador puede avanzar
	lw $t4, -4($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, -256($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, -260($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, -252($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, 4($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, 252($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, 256($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb
	lw $t4, 260($t1)
	beq $t4, 0xCCCCFF, randomOb
	beq $t4, 0x00ff00, randomOb

	# si no detecta problemas en la posición, procede a pintar el obstáculo, y suma 1 al contador de obstáculos $t8
	sw $t3, 0($t1)
	add $t8, $t8, 1 

jr $ra


#===============================================================================================
#-------------------------GENERADOR DE COMIDAS---------------------------------------------
#===============================================================================================
#============================================================================================================================================
# Función / Entrada / Salida
#--------------------------------------------------------------------------------------------------------------------------------------------
# randomCo / - / -
# Genera una posición pseudo aleatoria dependiente del seed seteado, y dibuja una comida en esa posición
#============================================================================================================================================

randomCo:

	li $a0, 0		# Número para el generador pseudo aleatorio (es 0 porque cuando se setea la seed se hace para este número)
	li $a1, 3584		# Límite máximo de número generado
	li $v0, 42		# syscall 42 (obtiene número pseudo aleatorio en $a0)
	syscall	
	
	la $t1 , display		# $t1 = display
	move $t4, $a0 			# $t4 = número pseudo aleatorio generado
	sll $t4, $t4, 2			# se multiplica por 4 para que calze con la dirección de display
	add $t1, $t4, $t1		# se le suma al lugar de inicio del arreglo de display para pintarlo
	addi $t3 , $zero , 0xFF6600 	# $t3 = color 0xFF6600
	
	# se obtiene el color actual de la dirección deseada para pintar, si es un jugador o un obstáculo se vuelve a generar otro número
	
	lw $t4, 0($t1)			
	beq $t4, 0x00ff00, randomCo 	# jugador
	beq $t4, 0xCCCCFF, randomCo 	# obstaculo
	
	sw $t3, 0($t1) 			# se pinta la comida
	
jr $ra

#===============================================================================================
#-----------FIN---------------------------------------------------------------------------------
#===============================================================================================
#===============================================================================================
# Función / Entrada / Salida
#-----------------------------------------------------------------------------------------------
# exit / - / -
# Pinta todo el display de negro y luego sale del programa
#===============================================================================================

exit: 
	la $t1 , display		# $t1 = display
	addi $t3 , $zero , 0x000000  	# $t3 = negro
	li $t4, 0 			# $t4 es i = 0 para el ciclo
	li $s1, 16384			# $s1 = 16348 (valor máximo del ciclo)
	add $t1, $t4, $t1 

	# Ciclo para pintar display negro	
	LOOPX: beq $t4, $s1, X
	sw $t3, 0($t1) 
	addi $t4, $t4, 4 
	addi $t1, $t1, 4 
	j LOOPX 

	# Se sale del programa usando syscall 10
	X:
	li $v0, 10 #exit
	syscall  
	
#===============================================================================================
#-----------------------LIMPIAR SCORE-----------------------------------------------------------
#===============================================================================================
#===========================================================================================================================
# Función / Entrada / Salida
#---------------------------------------------------------------------------------------------------------------------------
# ClearScore / - / -
# Limpia el score pintando la barra inferior del display
#===========================================================================================================================
ClearScore:
	
	# Se pinta con el color 0x426289 utilizando un ciclo que pinta desde la dirección 14336 hasta 16000 del display
	addi $t3 , $zero , 0x426289 	
	la $t1 , display 		# $t1 = display
	li $t4, 14336 			# $t4 = 14336
	add $t1, $t4, $t1		# $t1 = display+14336 = dirección donde comienza la barra de score

	# Ciclo que pinta cada dirección sumando 4 cada iteración
	LOOP2: beq $t4, 16000, salida 
	sw $t3, 0($t1) 
	addi $t4, $t4, 4 
	addi $t1, $t1, 4  
	j LOOP2 

salida: jr $ra

#=================================================================================================================================================================
# Funciones / Entrada / Salida
#-----------------------------------------------------------------------------------------------------------------------------------------------------------------
# "printNúmero", "printDNúmero" / - / -
# Imprimen un número específico en el score, las funciones que no llevan D en su label imprimen dígitos de unidad, las que si llevan imprimen dígitos de decena,
# el número que imprimen va explicitado en su label
#=================================================================================================================================================================

#-----------------------------------------------------
#		DIGITOS UNIDAD
#-----------------------------------------------------

printNueve:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15072( $t1 )
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra

printOcho:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	sw $t2 , 15072( $t1 )
	sw $t2 , 15080( $t1 )
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	sw $t2 , 15592( $t1 )
	sw $t2 , 15584( $t1 )
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra

printSiete:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
jr $ra


printSeis:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15072( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	sw $t2 , 15584( $t1 )
	
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra


printCinco:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15072( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra


printCuatro:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15072( $t1 )
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
jr $ra


printTres:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra

printDos:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15332( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15584( $t1 )
	
	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra


printUno:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	
	sw $t2 , 15592( $t1 )
	
	sw $t2 , 15848( $t1 )
jr $ra


printCero:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14816( $t1 )
	sw $t2 , 14820( $t1 )
	sw $t2 , 14824( $t1 )
	
	sw $t2 , 15072( $t1 )
	sw $t2 , 15080( $t1 )
	
	sw $t2 , 15336( $t1 )
	sw $t2 , 15328( $t1 )
	
	sw $t2 , 15592( $t1 )
	sw $t2 , 15584( $t1 )

	sw $t2 , 15848( $t1 )
	sw $t2 , 15844( $t1 )
	sw $t2 , 15840( $t1 )
jr $ra

#-----------------------------------------------------
#		DIGITOS DECENA
#-----------------------------------------------------

printDNueve:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15056( $t1 )
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc


printDOcho:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15056( $t1 )
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	sw $t2 , 15568( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc


printDSiete:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
j cc


printDSeis:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15056( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	sw $t2 , 15568( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc

printDCinco:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15056( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc


printDCuatro:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15056( $t1 )
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc


printDTres:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc

printDDos:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14800( $t1 )
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	sw $t2 , 15316( $t1 )
	sw $t2 , 15312( $t1 )
	
	sw $t2 , 15568( $t1 )
	
	sw $t2 , 15832( $t1 )
	sw $t2 , 15828( $t1 )
	sw $t2 , 15824( $t1 )
j cc


printDUno:

	la $t1 , display
	addi $t2 , $zero , 0x000000
	sw $t2 , 14804( $t1 )
	sw $t2 , 14808( $t1 )
	
	sw $t2 , 15064( $t1 )
	
	sw $t2 , 15320( $t1 )
	
	sw $t2 , 15576( $t1 )
	
	sw $t2 , 15832( $t1 )
j cc




#==================================================================================================================================
# Función / Entrada / Salida
#----------------------------------------------------------------------------------------------------------------------------------
# gameover / - / -
# Imprime la frase 'YOU DIED' (has muerto) en el display, luego realiza una espera de 4 segundos y se reinicia el juego
#==================================================================================================================================

gameover:

	la $t1 , display
	addi $t2 , $zero , 0xff0000 #Color rojo
	sw $t2 , 4176( $t1 )
	sw $t2 , 4184( $t1 )
	sw $t2 , 4192( $t1 )
	sw $t2 , 4196( $t1 )
	sw $t2 , 4200( $t1 )
	sw $t2 , 4208( $t1 )
	sw $t2 , 4216( $t1 )
	sw $t2 , 4228( $t1 )
	sw $t2 , 4232( $t1 )
	sw $t2 , 4244( $t1 )
	sw $t2 , 4252( $t1 )
	sw $t2 , 4256( $t1 )
	sw $t2 , 4264( $t1 )
	sw $t2 , 4268( $t1 )
	sw $t2 , 4432( $t1 )
	sw $t2 , 4440( $t1 )
	sw $t2 , 4448( $t1 )
	sw $t2 , 4456( $t1 )
	sw $t2 , 4464( $t1 )
	sw $t2 , 4472( $t1 )
	sw $t2 , 4484( $t1 )
	sw $t2 , 4492( $t1 )
	sw $t2 , 4500( $t1 )
	sw $t2 , 4508( $t1 )
	sw $t2 , 4520( $t1 )
	sw $t2 , 4528( $t1 )
	sw $t2 , 4692( $t1 )
	sw $t2 , 4704( $t1 )
	sw $t2 , 4712( $t1 )
	sw $t2 , 4720( $t1 )
	sw $t2 , 4728( $t1 )
	sw $t2 , 4740( $t1 )
	sw $t2 , 4748( $t1 )
	sw $t2 , 4756( $t1 )
	sw $t2 , 4764( $t1 )
	sw $t2 , 4768( $t1 )
	sw $t2 , 4776( $t1 )
	sw $t2 , 4784( $t1 )
	sw $t2 , 4948( $t1 )
	sw $t2 , 4960( $t1 )
	sw $t2 , 4968( $t1 )
	sw $t2 , 4976( $t1 )
	sw $t2 , 4984( $t1 )
	sw $t2 , 4996( $t1 )
	sw $t2 , 5004( $t1 )
	sw $t2 , 5012( $t1 )
	sw $t2 , 5020( $t1 )
	sw $t2 , 5032( $t1 )
	sw $t2 , 5040( $t1 )
	sw $t2 , 5204( $t1 )
	sw $t2 , 5216( $t1 )
	sw $t2 , 5220( $t1 )
	sw $t2 , 5224( $t1 )
	sw $t2 , 5232( $t1 )
	sw $t2 , 5236( $t1 )
	sw $t2 , 5240( $t1 )
	sw $t2 , 5252( $t1 )
	sw $t2 , 5256( $t1 )
	sw $t2 , 5268( $t1 )
	sw $t2 , 5276( $t1 )
	sw $t2 , 5280( $t1 )
	sw $t2 , 5288( $t1 )
	sw $t2 , 5292( $t1 )

	li $a0, 4000	# Se esperan 4000 milisegundos (4 segundos)
	li $v0, 32	# syscall 32 (sleep)
	syscall	

	#luego se reinicia el juego	
j Start


#========================================================================================================================================
# Función / Entrada / Salida
#----------------------------------------------------------------------------------------------------------------------------------------
# reset / - / $t7 contiene display
# Inicializa todos los registros a los valores iniciales que requiere el programa para su correcto funcionamiento
#========================================================================================================================================

reset:	
	
	la $t1 , display		# Se carga la dirección de display en $t1
	addi $t3 , $zero , 0x000000 	# $t3 = 0x000000 (Color negro)
	li $t4, 0			# $t4 es i = 0
	li $s1, 14336			# $s1 = 14336 (límite del loop para que se limpie la pantalla sin borrar la barra del score
	add $t1, $t4, $t1 		# $t1 = posición inicial de display
	
	# Ciclo que almacena el color negro en cada elemento del display hasta antes del borde del score
	LOOPr: beq $t4, $s1, outR
	sw $t3, 0($t1) 
	addi $t4, $t4, 4 
	addi $t1, $t1, 4 
	j LOOPr 
	
	outR:

	# Se asignan los valores iniciales a cada registro y arreglo de memoria
	
	# Posición inicial de la cabeza de la serpiente
	la $t1, status
	li $t0, 32
	sw $t0, 0($t1)
	li $t0, 16
	sw $t0, 4($t1)
	# Posición inicial de la cola de la serpiente
	la $t1, localizacionCola
	li $t0, 32
	sw $t0, 0($t1)
	li $t0, 17
	sw $t0, 4($t1)
	# Dirección inicial de la cola de la serpiente
	la $t1, direccionCola
	li $t0, 119
	sw $t0, 0($t1)
	# Contadores de score unidades y decenas, estado de actualización de score, además la memoria donde se almacena el último valor ingresado
	la $t1, status
	li $t0, 0
	la $a0, 0xffff0004
	sw $t0, 8($t1)
	sw $t0, 12($t1)
	sw $t0, 16($t1)
	sw $t0, 0($a0)
	li $a0, 0
	li $a1, 0
	li $a2, 0
	li $a3, 0
	li $t0, 0
	li $t1, 0
	li $t2, 0
	li $t3, 0
	li $t4, 0
	li $t5, 0
	li $t6, 0
	li $t7, 0
	li $t8, 0
	li $t9, 0
	li $s0, 0
	li $s1, 0
	li $s2, 0
	li $s3, 0
	li $s4, 0
	# Se dibuja en el display la cabeza de la serpiente en la posición inicial
	la $t1 , display
	addi $t2 , $zero , 0x00ff00 #VERDE
	sw $t2 , 4224( $t1 )
	
	#Se asigna display a $t7 y se le da la dirección actual de la cabeza sumándosela
	move $t7, $t1
	addi $t7, $t7, 4224
	
	#Se pinta la barra del marcador con el color 0x426289 almacenado en $t3, desde la posición 14336 hasta la 163834 del display
	addi $t3 , $zero , 0x426289 
	li $t4, 14336
	li $s1, 16384
	add $t1, $t4, $t1 

	LOOP: beq $t4, $s1, out 
		sw $t3, 0($t1) 
		addi $t4, $t4, 4 
		addi $t1, $t1, 4 
		j LOOP 
	out:
	
jr $ra
