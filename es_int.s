* Inicialización  del SP y el PC
****************************************
        ORG     $0
        DC.L    $8000           * Pila
        DC.L    INICIO          * PC

        ORG     $400

* Definicion de equivalencias
****************************************

MR1A    EQU     $effc01       * de modo A (escritura)
MR2A    EQU     $effc01       * de modo A (2 escritura)
SRA     EQU     $effc03       * de estado A (lectura)
CSRA    EQU     $effc03       * de seleccion de reloj A (escritura)
CRA     EQU     $effc05       * de control A (escritura)
TBA     EQU     $effc07       * buffer transmision A (escritura)
RBA     EQU     $effc07       * buffer recepcion A  (lectura)

ACR     EQU     $effc09       * de control auxiliar
IMR     EQU     $effc0B
ISR     EQU     $effc0B       * de estado de interrupcion A (lectura)

MR1B    EQU     $effc11       * de modo B (escritura)
MR2B    EQU     $effc11       * de modo B (2 escritura)
CRB     EQU     $effc15       * de control A (escritura)
TBB     EQU     $effc17       * buffer transmision B (escritura)
RBB     EQU     $effc17       * buffer recepcion B (lectura)
SRB     EQU     $effc13       * de estado B (lectura)
CSRB    EQU     $effc13       * de seleccion de reloj B (escritura)

IVR     EQU     $effc19       * Vector de interrupcion

CR      EQU     $0D           * Carriage Return
LF      EQU     $0A           * Line Feed
FLAGT   EQU     2             * Flag de transmision
FLAGR   EQU     0             * Flag de recepcion

IMR_COPIA:   DC.B    0	      * Copia del IMR para lecturas

**********************************************************************************************

**************************** INIT *************************************************************
        ORG $2400
INIT:
        MOVE.B          #%00010000,CRA      	* Reinicia el puntero MR1
        MOVE.B          #%00010000,CRB     	* Reinicia el puntero MR1
        MOVE.B          #%00000011,MR1A    	* 8 bits por caracter.
        MOVE.B          #%00000011,MR1B     	* 8 bits por caracter.
        MOVE.B          #%00000000,MR2A     	* Eco desactivado.
        MOVE.B          #%00000000,MR2B     	* Eco desactivado.
        MOVE.B          #%11001100,CSRA     	* Velocidad = 38400 bps.
        MOVE.B          #%11001100,CSRB     	* Velocidad = 38400 bps.
        MOVE.B          #%00000000,ACR      	* Velocidad = 38400 bps.
        MOVE.B          #%00000101,CRA   	* Transmision y recepcion activados A
        MOVE.B          #%00000101,CRB          * Transmisión y recepción activados B
        MOVE.B          #%00100010,IMR
        MOVE.B          #%00100010,IMR_COPIA 	* Copia del vector de interrupcion
        MOVE.B          #%01000000,IVR      	* Vector de interrupcion a H'40
        MOVE.L          #RTI,$100               * Actualizacion de la tabla de rutinas de interrupcion
	BSR             INI_BUFS
	RTS

**************************** FIN INIT *********************************************************

**************************** PRINT ************************************************************

PRINT:
        LINK A6,#-20		* Reserva de espacio en pila para 5 variables locales
	MOVE.L A5,-4(A6)	* Guardo los registros que utilizo en PRINT
	MOVE.W D1,-8(A6)
	MOVE.W D2,-12(A6)
	MOVE.L D3,-16(A6)
	MOVE.L D4,-20(A6)
	MOVE.L 8(A6),A5		* Direccion del Buffer
	MOVE.W 12(A6),D1	* Dato de Descriptor
	MOVE.W 14(A6),D2	* Dato de Tamano
        EOR.L D3,D3             * Contador de caracteres a 0
        EOR.L D0,D0             * Inicializamos el resultado a 0
        CMP.W #0,D1             * Comparamos el descriptor con 0 para saber si es la linea A
        BEQ ESC_A   
        CMP.W #1,D1             * Comparamos el descriptor con 1 para saber si es la linea B
        BEQ ESC_B  
        SUB.L #1,D0             * Se introduce el valor -1 en D0 para indicar error 
        BRA FIN_PERR            * Fin de PRINT con descriptor erroneo

ESC_A:
        CMP.W D3,D2             * Se comprueba si se han transmitido todos los caracteres
        BEQ FINP_A
        MOVE.B (A5)+,D1         * Metemos el caracter en D1 y postincrementamos el puntero al buffer
        MOVE.L #2,D0            * Buffer A de transmision
        BSR ESCCAR  
        CMP.L #$ffffffff,D0     * Miramos si el buffer esta lleno (devuelve -1 en D0)
        BEQ FINP_A
        ADD.W #1,D3             * Sumamos uno al contador de caracteres
        BRA ESC_A
        
FINP_A:
        CMP.W #0,D2             * Miramos si el tamano a transmitir es cero
        BEQ FIN_PRINT       
        MOVE.W SR,D4            * Almaceno el valor previo de SR
        MOVE.W #$2700,SR        * Se inhiben las interrupciones y se activa el modo supervisor
        BSET #0,IMR_COPIA       * Cambiamos el bit 0 de la copia del IMR para activar la transmision del puerto A
        MOVE.B IMR_COPIA,IMR    * Introducimos el valor de la copia del IMR al IMR al no poder modificarlo directamente
        MOVE.W D4,SR            * Restauramos el registro de estado 
        BRA FIN_PRINT

ESC_B:
        CMP.W D3,D2             * Se comprueba si se han transmitido todos los caracteres
        BEQ FINP_B
        MOVE.B (A5)+,D1         * Metemos el caracter en D1 y postincrementamos el puntero al buffer
        MOVE.L #3,D0            * Buffer B de transmision
        BSR ESCCAR  
        CMP.L #$ffffffff,D0     * Miramos si el buffer esta lleno (devuelve -1 en D0)
        BEQ FINP_B
        ADD.W #1,D3             * Sumamos uno al contador de caracteres
        BRA ESC_B

FINP_B:
        CMP.W #0,D2             * Miramos si el tamano a transmitir es 0
        BEQ FIN_PRINT       
        MOVE.W SR,D4            * Almaceno el valor previo de SR
        MOVE.W #$2700,SR        * Se inhiben las interrupciones y se activa el modo supervisor
        BSET #4,IMR_COPIA       * Cambiamos el bit 4 de la copia del IMR para activar la transmision del puerto B
        MOVE.B IMR_COPIA,IMR    * Introducimos el valor de la copia del IMR al IMR al no poder modificarlo directamente
        MOVE.W D4,SR            * Restauramos el registro de estado 

FIN_PRINT:
        EOR.L D0,D0             * Inicializamos a 0 el registro resultado
        OR.L D3,D0              * Cargamos el numero total de caracteres impresos en D0

FIN_PERR:
        MOVE.L -4(A6),A5 	* Retomamos los parametros de PRINT
	MOVE.L -8(A6),D1
	MOVE.L -12(A6),D2
	MOVE.L -16(A6),D3
	MOVE.L -20(A6),D4
        UNLK A6                  * Rompemos el marco de pila
        RTS

**************************** FIN PRINT *******************************************************

**************************** SCAN ************************************************************

SCAN: 
        LINK A6,#-16		* Reserva de espacio en pila para 4 variables locales
	MOVE.L A0,-4(A6)	* Salvado de los registros que utilizamos en SCAN
	MOVE.W D1,-8(A6)
	MOVE.W D2,-12(A6)
	MOVE.L D3,-16(A6)
        MOVE.L 8(A6),A0		* Direccion del Buffer
	MOVE.W 12(A6),D1	* Dato de Descriptor
	MOVE.W 14(A6),D2	* Dato de Tamano
        EOR.L D3,D3             * Inicializamos a cero el contador de caracteres
        EOR.L D0,D0             * Inicializamos el resultado a cero
        CMP.W #0,D1             * Si el descriptor es 0 entonces la lectura sera por la linea A
        BEQ LEC_A   
        CMP.W #1,D1             * Si el descriptor es 1 entonces la lectura sera por la linea B
        BEQ LEC_B  
        SUB.L #1,D0 
        BRA FIN_SERR            * Si no es ni 0 ni 1 entonces se produce un error

LEC_A:
        CMP.W D3,D2             * Se comprueba si se han leido todos los caracteres
        BEQ FIN_SCAN
        MOVE.L #0,D0            * Buffer A de recepcion
        BSR LEECAR
        CMP.L #$ffffffff,D0     * Miramos si hay mas caracteres a leer o no
        BEQ FIN_SCAN
        ADD.L #1,D3             * Sumamos uno al contador de caracteres
        MOVE.B D0,(A0)+         * Metemos el caracter en el buffer 
        BRA LEC_A
     
LEC_B:     
        CMP.L D3,D2             * Se comprueba si se han leido todos los caracteres
        BEQ FIN_SCAN
        MOVE.L #1,D0            * Buffer B de recepcion
        BSR LEECAR
        CMP.L #$ffffffff,D0     * Miramos si hay mas caracteres o no
        BEQ FIN_SCAN
        ADD.L #1,D3             * Sumamos uno al contador
        MOVE.B D0,(A0)+         * Metemos el caracter en el buffer 
        BRA LEC_B
     
FIN_SCAN:
        EOR.L D0,D0             * Inicializamos a 0 el registro resultado
        OR.L D3,D0              * Cargamos el numero total de caracteres leidos en D0
FIN_SERR:
	MOVE.L -4(A6),A0        * Se recuperan los registros guardados en pila (ERRATA CORREGIDA)
	MOVE.L -8(A6),D1
	MOVE.L -12(A6),D2
	MOVE.L -16(A6),D3
	UNLK A6 		* Destruccion del marco de pila
	RTS
		
************************************* RTI ****************************************************

RTI:
        MOVEM.L D0-D5,-(A7)     * Reserva de espacio en pila para registros usados en RTI
        MOVE.B IMR_COPIA,D4     * Se guarda el byte del IMR mediante la copia del mismo
        MOVE.B ISR,D5           * Se guarda el byte del ISR
        AND.B D4,D5             * Se comparan para ver los bits que tienen en comun
        BTST #1,D5              * neg(D5) -> Z / Buscamos un 1, que en Z es un 0
        BNE REC_A               * Devuelve 1 si en Z hay un 0 y si lo es es recepcion de A
        BTST #5,D5              * neg(D5) -> Z / Buscamos un 1, que en Z es un 0
        BNE REC_B               * Devuelve 1 si en Z hay un 0 y si lo es es recepcion de B
        BTST #0,D5              * neg(D5) -> Z / Buscamos un 1, que en Z es un 0
        BNE TRA_A               * Devuelve 1 si en Z hay un 0 y si lo es es transmision de A
        BTST #4,D5              * neg(D5) -> Z / Buscamos un 1, que en Z es un 0
        BNE TRA_B               * Devuelve 1 si en Z hay un 0 y si lo es es transmision de B

FIN_RTI:
        MOVEM.L (A7)+,D0-D5     * Se recuperan los registros usados en RTI guardados en pila
        RTE

REC_A: 
        EOR.L D0,D0             * Descriptor linea de recepcion A (0)
        EOR.L D1,D1             * Inicializacion de D1 a 0
        MOVE.B RBA,D1           * Cargo el caracter en D1
        BSR ESCCAR
        CMP.L #$ffffffff,D0     * Si la subrutina devuelve -1 es porque el buffer esta lleno 
        BEQ REC_FA              * Buffer lleno (full) de linea A
        BRA FIN_RTI

REC_B: 
        MOVE.L #1,D0            * Descriptor linea de recepcion B (1)
        EOR.L D1,D1             * Inicializacion de D1 a 0
        MOVE.B RBB,D1           * Cargo el caracter en D1
        BSR ESCCAR
        CMP.L #$ffffffff,D0     * Si la subrutina devuelve -1 es porque el buffer esta lleno 
        BEQ REC_FB              * Buffer lleno (full) de linea B
        BRA FIN_RTI
        
REC_FA:
        BCLR #1,IMR_COPIA       * Deshabilitamos la peticion de interrupcion de recepcion de la linea A
        MOVE.B IMR_COPIA,IMR    * Actualizamos el IMR    
        BRA FIN_RTI  

REC_FB:
        BCLR #5,IMR_COPIA       * Deshabilitamos la peticion de interrupcion de recepcion de la linea B
        MOVE.B IMR_COPIA,IMR    * Actualizamos el IMR  
        BRA FIN_RTI

TRA_A: 
        MOVE.L #2,D0            * Descriptor linea de transmision A (2)
        BSR LEECAR
        CMP.L #$ffffffff,D0     * Si la subrutina devuelve -1 es porque el buffer esta vacio 
        BEQ TRA_EA              * Buffer vacio (empty) de linea A
        MOVE.B D0,TBA           * Cargo el caracter devuelto en TBA
        BRA FIN_RTI     

TRA_B: 
        EOR.L #3,D0             * Descriptor linea de transmision B (3)
        BSR LEECAR
        CMP.L #$ffffffff,D0     * Si la subrutina devuelve -1 es porque el buffer esta vacio 
        BEQ TRA_EB              * Buffer vacio (empty) de linea B
        MOVE.B D0,TBB           * Cargo el caracter devuelto en TBB
        BRA FIN_RTI    

TRA_EA:
        BCLR #0,IMR_COPIA       * Deshabilitamos la peticion de interrupcion de transmision de la linea A
        MOVE.B IMR_COPIA,IMR    * Actualizamos el IMR
        BRA FIN_RTI

TRA_EB:
        BCLR #4,IMR_COPIA       * Deshabilitamos la peticion de interrupcion de transmision de la linea B
        MOVE.B IMR_COPIA,IMR    * Actualizamos el IMR
        BRA FIN_RTI

**************************** FIN PROGRAMA PRINCIPAL ******************************************

**************************** PROGRAMA PRINCIPAL **********************************************

BUFFER: 
        DS.B    3000            * Buffer para lectura y escritura de caracteres
PARDIR: 
        DC.L    0               * Direccion que se pasa como parametro
PARTAM: 
        DC.W    0               * Tamano que se pasa como parametro
CONTC: 
        DC.W    0               * Contador de caracteres a imprimir

DESA:   EQU     0               * Descriptor linea A
DESB:   EQU     1               * Descriptor linea B
TAMBS:  EQU     3000               * Tamano de bloque para SCAN
TAMBP:  EQU     3000               * Tamano de bloque para PRINT

* Manejadores de excepciones

INICIO: 
        MOVE.L #BUS_ERROR,8     * Bus error handler
        MOVE.L #ADDRESS_ER,12   * Address error handler
        MOVE.L #ILLEGAL_IN,16   * Illegal instruction handler
        MOVE.L #PRIV_VIOLT,32   * Privilege violation handler
        MOVE.L #ILLEGAL_IN,40   * Illegal instruction handler
        MOVE.L #ILLEGAL_IN,44   * Illegal instruction handler
        BSR INIT
        MOVE.W #$2000,SR        * Permite interrupciones

BUCPR: 
        MOVE.W #TAMBS,PARTAM    * Inicializa parametro de tamano
        MOVE.L #BUFFER,PARDIR   * Parametro BUFFER = comienzo del buffer
        
OTRAL: 
        MOVE.W #1000,-(A7)    * Tamano de bloque
        MOVE.W #DESB,-(A7)      * Puerto A
        MOVE.L PARDIR,-(A7)     * Direccion de lectura

ESPL: 
        BSR SCAN
        ADD.L #8,A7             * Restablece la pila
        ADD.L D0,PARDIR         * Calcula la nueva direccion de lectura
        SUB.W D0,PARTAM         * Actualiza el numero de caracteres ledos
        BNE OTRAL               * Si no se han ledo todas los caracteres del bloque se vuelve a leer
        MOVE.W #TAMBS,CONTC     * Inicializa contador de caracteres a imprimir
        MOVE.L #BUFFER,PARDIR   * Parametro BUFFER = comienzo del buffer

OTRAE: 
        MOVE.W #1000,PARTAM    * Tamano de escritura = Tamano de bloque

ESPE: 
        MOVE.W #1000,-(A7)     * Tamano de escritura
        MOVE.W #DESA,-(A7)      * Puerto B
        MOVE.L PARDIR,-(A7)     * Direccion de escritura
        BSR PRINT
        ADD.L #8,A7             * Restablece la pila
        ADD.L D0,PARDIR         * Calcula la nueva direccion del buffer
        SUB.W D0,CONTC          * Actualiza el contador de caracteres
        BEQ SALIR               * Si no quedan caracteres se acaba
        SUB.W D0,PARTAM         * Actualiza el tama~no de escritura
        BNE ESPE                * Si no se ha escrito todo el bloque se insiste
        CMP.W #TAMBP,CONTC      * Si el no de caracteres que quedan es menor que el tamano establecido se imprime ese numero
        BHI OTRAE               * Siguiente bloque
        MOVE.W CONTC,PARTAM
        BRA ESPE                * Siguiente bloque
SALIR: 
        BRA BUCPR

BUS_ERROR: 
        BREAK 
        NOP
ADDRESS_ER: 
        BREAK 
        NOP
ILLEGAL_IN: 
        BREAK 
        NOP
PRIV_VIOLT: 
        BREAK 
        NOP

**************************** FIN PROGRAMA PRINCIPAL ******************************************


INCLUDE bib_aux.s
