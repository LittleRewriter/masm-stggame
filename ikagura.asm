; a masm program to replicate famous STG, Ikagura
.686
.model flat, stdcall
option casemap :none

	printf			PROTO C :ptr sbyte, :vararg
	time			PROTO C :dword
	srand			PROTO C :dword
	rand			PROTO C
	getchar			PROTO C

include	\masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\gdi32.inc
include \masm32\include\opengl32.inc
include \masm32\include\glu32.inc
include \masm32\include\msvcrt.inc
include \masm32\include\Comdlg32.inc

includelib \masm32\lib\gdi32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\msvcrt.lib
includelib \masm32\lib\Comdlg32.lib
includelib \masm32\lib\opengl32.lib
includelib \masm32\lib\glu32.lib

PFD_MAIN_PLANE		equ	0
PFD_TYPE_COLORINDEX	equ	1
PFD_TYPE_RGBA		equ	0
PFD_DOUBLEBUFFER	equ	1
PFD_DRAW_TO_WINDOW	equ	4
PFD_SUPPORT_OPENGL	equ	020h

.const
WHITE			word	1
BLACK			word	2
_WIDTH			word	300
_HEIGHT			word	400
INTERVAL		word	20
INIT_X			word	150
INIT_Y			word	399

FMTCHAR			byte	"%c", 0
FMTINT			byte	"%d ", 0

MAXCOUNT		dword	1024

GAMEOVER		byte	"GAME OVER!", 10, 0

.data

; ##########################################
; ##  this region is for gameplay         ##
; ##########################################

; score
score			word	0

; player is white if playerColor is 1, black if 2
playerColor		word	1

; player's HP
playerHP		word	1000

; restrict between two frames
bulletRes		word	1
moveRes			word	3

; player's moving direction
; equals to 0 if don't move, 1 for forward, 2 for backward
pVertical		word	0
; equals to 0 if don't move, 1 for left, 2 for right
pHorizonal		word	0

; to be continued...
; energy of player's fighter, lowest 0, highest 300
; increase when hit by same color ememy bullet
; determine the level of fighter, 0-100 L1, 101-200 L2, 201-300 L3
; can consume 50 energy to release a bomb
playerEnergy	word	1

; map size is 300w*400h
; describe the position of player
; position: x for left and right, y for up and down
; x: lower is left y:lower is up
playerX			word	150
playerY			word	380

; two dword describe an enemy
; 63-48 enemy remain hp
; 47-32 enemy type, equals to 0 if is dead, 1 or 5 if white, 2 or 6 if black
; 31-16 enemy x
; 15-0 enemy y

; use a loop(circle) queue to save. from bottom to top. top point to next null position(may overflat existed one).
; in fact, high dword and lower dword usually work independently (cause it's 32 bit!)
enemyList		dword	2048 dup(0), 0
enemyBtm		dword	0
enemyTop		dword	0

; a dword describe a bullet
; 63-48 remained (may describe bullet direction)
; 47-32 bullet type, equals to 0 if is gone, 1 if is white, 2 if is black
; 31-16 bullet x
; 15-0 bullet y

; list to get all bullets
playerBulList	dword	2048 dup(0), 0
playerBulBtm	dword	0
playerBulTop	dword	0
enemyBulList	dword	2048 dup(0), 0
enemyBulBtm		dword	0
enemyBulTop		dword	0

; ########################################
; ### this region is for rendering #######
; ########################################

	szWindowTitle       db "TestOpenGL",0
	szClassName         db "Win32SDI_Class",0
	szCloseHint         db "Do you want to close?",0

	CommandLine         dd 0
	hWnd                dd 0
	MainHDC             dd 0
	OpenDC              dd 0
	hInstance           dd 0
	PixFrm              PIXELFORMATDESCRIPTOR <>

; global configs
    BackgroundColor         dd 0.0, 0.0, 0.0, 0.0
    CameraFOV           	dq 45.0
    CameraAspect        	dq 1.0
    CameraZNear         	dq 0.01
    CameraZFar          	dq 1000.0

    CameraL             	dq -6.0
    CameraR             	dq 6.0
    CameraT             	dq 8.0
    CameraB             	dq -8.0
	CameraW					dq 12.0
	CameraH					dq -16.0

	BulletZPos				dd -4.0
	PlayerZPos				dd -5.0
	EnemyZPos				dd -5.0

; constants
    FValue0         dd 0.0
    FValue1         dd 1.0
    FValue90        dd 90.0
    FValueM90       dd -90.0
    DValue0         dq 0.0
    DValue1         dq 1.0
    DValue90        dq 90.0
    DValueM90       dq -90.0

; light info
    LightAmbient		    dd 0.2,0.0,0.0,1.0
    LightDiffuse            dd 1.0,1.0,1.0,1.0
    LightPosition           dd 1.0, 1.0, 1.0, 0.0

    Light2Ambient		    dd 0.2,0.0,0.0,1.0
    Light2Diffuse           dd 1.0,1.0,1.0,1.0
    Light2Position          dd -1.0, 1.0, 1.0, 0.0


; coords of a standard box
    ; front
    BoxSurface1Verta    dd -0.5,-0.5,-0.5
    BoxSurface1Vertb    dd -0.5,-0.5,0.5
    BoxSurface1Vertc    dd 0.5,-0.5,0.5
    BoxSurface1Vertd    dd 0.5,-0.5,-0.5
    BoxSurface1Norm     dd 0.0,-1.0,0.0
    ; bottom
    BoxSurface2Verta    dd -0.5,-0.5,-0.5
    BoxSurface2Vertb    dd 0.5,-0.5,-0.5
    BoxSurface2Vertc    dd 0.5,0.5,-0.5
    BoxSurface2Vertd    dd -0.5,0.5,-0.5
    BoxSurface2Norm     dd 0.0,0.0,1.0
    ; back
    BoxSurface3Verta    dd 0.5,0.5,-0.5
    BoxSurface3Vertb    dd 0.5,0.5,0.5
    BoxSurface3Vertc    dd -0.5,0.5,0.5
    BoxSurface3Vertd    dd -0.5,0.5,-0.5
    BoxSurface3Norm     dd 0.0,1.0,0.0
    ; top
    BoxSurface4Verta    dd 0.5,0.5,0.5
    BoxSurface4Vertb    dd 0.5,-0.5,0.5
    BoxSurface4Vertc    dd -0.5,-0.5,0.5
    BoxSurface4Vertd    dd -0.5,0.5,0.5
    BoxSurface4Norm     dd 0.0,0.0,-1.0
    ; left
    BoxSurface5Verta    dd -0.5,-0.5,-0.5
    BoxSurface5Vertb    dd -0.5,0.5,-0.5
    BoxSurface5Vertc    dd -0.5,0.5,0.5
    BoxSurface5Vertd    dd -0.5,-0.5,0.5
    BoxSurface5Norm     dd -1.0,0.0,0.0
    ; right
    BoxSurface6Verta    dd 0.5,-0.5,-0.5
    BoxSurface6Vertb    dd 0.5,-0.5,0.5
    BoxSurface6Vertc    dd 0.5,0.5,0.5
    BoxSurface6Vertd    dd 0.5,0.5,-0.5
    BoxSurface6Norm     dd 1.0,0.0,0.0

; scale and position of player
    PlayerMainScale     dd 0.6, 0.6, 0.6
    PlayerMainPos       dd 0, 0, -5.0
    PlayerBodyAmbient   dd 0.3, 0.9, 0.3, 1.0
    PlayerBodyDiffuse   dd 0.3, 1.0, 0.3, 1.0
    PlayerBodySpecular  dd 1.0, 1.0, 1.0, 1.0
    PlayerLWingPos      dd -0.8, -0.2, 0.0
    PlayerLWingScale    dd 0.6, 0.2, 1.0
    PlayerLGunPos       dd -0.8, 0.3, -0.35
    PlayerLGunScale     dd 0.15, 0.15, 0.4
    PlayerRWingPos      dd 0.8, -0.2, 0.0
    PlayerRWingScale    dd 0.6, 0.2, 1.0
    PlayerRGunPos       dd 0.8, 0.3, -0.35
    PlayerRGunScale     dd 0.15, 0.15, 0.4 
    PlayerHeadPos       dd 0.0, 0.8, -1.0
    PlayerHeadScale     dd 0.4, 0.4, 0.4
    PlayerGunZPos       dq 1.0
    PlayerGunBaseRad    dq 1.0
    PlayerGunTopRad     dq 1.0
    PlayerGunSlice      dd 32
    PlayerGunStack      dd 16
    PlayerGunAmb        dd 0.96,0.64,0.38,1.0
    PlayerGunDiff       dd 0.54,0.27,0.07,1.0  
    PlayerTopAmb        dd 0.72,0.52,0.04,1.0
    PlayerTopDiff       dd 1.0,0.84,0.0,1.0 
    PlayerTopSlice      dd 32

; scale and position of enemy
    EnemyMainScale     dd 0.6, 0.6, 0.6
    EnemyTempPos       dd 1.0, 1.0, -5.0
    EnemyBodyAmbient   dd 0.1, 0.1, 0.44, 1.0
    EnemyBodyDiffuse   dd 0.39, 0.58, 0.93, 1.0
    EnemyBodySpecular  dd 0.9, 0.9, 0.9, 1.0
    EnemyShiness       dd 128,128,128,128
    EnemyLWingPos      dd -0.8, 0.2, 0.0
    EnemyLWingScale    dd 0.6, 0.2, 1.0
    EnemyLGunPos       dd -0.8, 0.3, -0.1
    EnemyLGunScale     dd 0.15, 0.15, 0.4
    EnemyRWingPos      dd 0.8, 0.2, 0.0
    EnemyRWingScale    dd 0.6, 0.2, 1.0
    EnemyRGunPos       dd 0.8, 0.3, -0.1
    EnemyRGunScale     dd 0.15, 0.15, 0.4 
    EnemyHeadPos       dd 0.0, -0.8, -1.0
    EnemyHeadScale     dd 0.4, 0.4, 0.4
    EnemyGunZPos       dq 1.0
    EnemyGunBaseRad    dq 1.0
    EnemyGunTopRad     dq 1.0
    EnemyGunSlice      dd 32
    EnemyGunStack      dd 16
    EnemyGunAmb        dd 0.96,0.64,0.38,1.0
    EnemyGunDiff       dd 0.54,0.27,0.07,1.0  
    EnemyTopAmb        dd 0.54,0.47,0.37,1.0
    EnemyTopDiff       dd 0.93,0.50,0.93,1.0 
    EnemyTopSlice      dd 32

; attributes of bullet
    BulletTempPos       dd -1.0,-1.0,-3.0
    BulletTempPos2      dd -1.0,1.0,-3.0
    BulletScale         dd 0.075, 0.3, 0.1
    BulletSlices        dd 12
    EnemyBulletAmb      dd 0.69,0.19,0.38,1.0
    EnemyBulletDiff     dd 1.0,0.71,0.75,1.0
    PlayerBulletAmb     dd 0.69,0.19,0.38,1.0
    PlayerBulletDiff    dd 1.0,0.71,0.75,1.0

.code

; ###########################################
; ########## function declarations ##########
; ###########################################

GlInit				PROTO 
ResizeObject		PROTO :DWORD, :DWORD
GlDrawCube			PROTO
GlDrawCylinder		PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
GlDrawCylinder		PROTO :DWORD, :DWORD, :DWORD, :DWORD
GlDrawCone			PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD
GenerateGlScale		PROTO :DWORD
GenerateGlPos		PROTO :DWORD
GenerateGlRotationX PROTO :DWORD
DrawPlayerPlane		PROTO :DWORD
DrawEnemyPlane		PROTO :DWORD
DrawPlayerBullet	PROTO :DWORD
DrawEnemyBullet		PROTO :DWORD
remapXYToPos		PROTO :DWORD, :DWORD, :REAL4
renderEnemyBullet	PROTO
renderPlayerBullet  PROTO
renderEnemy			PROTO
renderPlayer		PROTO
getPos				PROTO :WORD, :WORD
cursorXY			PROTO :WORD, :WORD
checkHitbox			PROTO :DWORD, :DWORD
checkEnemyHit		PROTO
checkPlayerHit		PROTO
addEBullet			PROTO :DWORD, :DWORD
addEnemy			PROTO :DWORD, :DWORD
addPBullet			PROTO
generateEBullet		PROTO
generateEnemy		PROTO
moveBullet			PROTO
moveEnemy			PROTO
movePlayer			PROTO
playerChange		PROTO
playerShoot			PROTO
readOpr				PROTO
resetLock			PROTO
initGame			PROTO
MainCallback		PROTO :DWORD, :DWORD, :DWORD, :DWORD
showScreen			PROTO
gameOver			PROTO
startMenu			PROTO
pauseMenu			PROTO
MainLoop			PROTO
MainProg			PROTO :DWORD, :DWORD


; ###########################################
; ###### this region is for rendering #######
; ###########################################

GlInit PROC
    
    invoke glLightfv, GL_LIGHT0, GL_AMBIENT, addr LightAmbient
    invoke glLightfv, GL_LIGHT0, GL_DIFFUSE, addr LightDiffuse
    invoke glLightfv, GL_LIGHT0, GL_POSITION, addr LightPosition
    invoke glEnable, GL_LIGHT0

    ; invoke glLightfv, GL_LIGHT1, GL_AMBIENT, addr Light2Ambient
    ; invoke glLightfv, GL_LIGHT1, GL_DIFFUSE, addr Light2Diffuse
    ; invoke glLightfv, GL_LIGHT0, GL_POSITION, addr Light2Position
    ; invoke glEnable, GL_LIGHT1

    invoke glEnable, GL_DEPTH_TEST
    invoke glEnable, GL_LIGHTING
    invoke glEnable, GL_CULL_FACE
    invoke glShadeModel, GL_SMOOTH
    invoke glEnable, GL_NORMALIZE
    ret
GlInit ENDP

ResizeObject PROC ParentW: DWORD, ParentH: DWORD
    invoke glViewport, 0, 0, ParentW, ParentH
    invoke glMatrixMode, GL_PROJECTION
    invoke glLoadIdentity
    invoke glOrtho, DWORD PTR CameraL, DWORD PTR CameraL+4,
            DWORD PTR CameraR, DWORD PTR CameraR+4,
            DWORD PTR CameraB, DWORD PTR CameraB+4,
            DWORD PTR CameraT, DWORD PTR CameraT+4,
            DWORD PTR CameraZNear, DWORD PTR CameraZNear+4,
            DWORD PTR CameraZFar, DWORD PTR CameraZFar+4
    ; invoke gluPerspective, DWORD PTR CameraFOV, DWORD PTR CameraFOV+4,
    ;         DWORD PTR CameraAspect, DWORD PTR CameraAspect+4,
    ;         DWORD PTR CameraZNear, DWORD PTR CameraZNear+4,
    ;         DWORD PTR CameraZFar, DWORD PTR CameraZFar+4
    invoke glMatrixMode, GL_MODELVIEW
    invoke glLoadIdentity
    ret
ResizeObject ENDP

GlDrawCube PROC
    ; front
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface1Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface1Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface1Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface1Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface1Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ; bottom
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface2Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface2Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface2Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface2Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface2Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ; back
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface3Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface3Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface3Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface3Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface3Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ; top
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface4Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface4Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface4Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface4Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface4Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ; left
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface5Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface5Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface5Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface5Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface5Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ; right
    invoke glBegin, GL_POLYGON
      lea eax, BoxSurface6Norm
      invoke glNormal3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface6Verta
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface6Vertb
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface6Vertc
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
      lea eax, BoxSurface6Vertd
      invoke glVertex3f, DWORD PTR [eax], DWORD PTR [eax+4], DWORD PTR [eax+8]
    invoke glEnd
    ret
GlDrawCube ENDP 

GlDrawCylinder PROC     AmbColor    :DWORD,
                        DiffColor   :DWORD,
                        BaseRad     :DWORD,
                        TopRad      :DWORD,
                        Height      :DWORD,
                        Slices      :DWORD,
                        Stacks      :DWORD 
    LOCAL GlCylinder: DWORD
    invoke gluNewQuadric
    mov GlCylinder, eax
    invoke gluQuadricDrawStyle, GlCylinder, GLU_FILL
    invoke gluQuadricNormals, GlCylinder, GLU_SMOOTH
    invoke glMaterialfv, GL_FRONT, GL_AMBIENT, AmbColor
    invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, DiffColor
    mov eax, BaseRad
    mov ebx, TopRad
    mov ecx, Height
    invoke gluCylinder, GlCylinder, [eax], [eax+4],
        [ebx], [ebx+4], [ecx], [ecx+4], Slices, Stacks
    mov eax, GlCylinder
    ret
GlDrawCylinder ENDP

GlDrawSphere PROC       AmbColor    :DWORD,
                        DiffColor   :DWORD,
                        Radius      :DWORD,
                        Parts       :DWORD
    LOCAL GlSphere: DWORD
    invoke gluNewQuadric
    mov GlSphere, eax
    invoke gluQuadricDrawStyle, GlSphere, GLU_FILL
    invoke gluQuadricNormals, GlSphere, GLU_SMOOTH
    invoke glMaterialfv, GL_FRONT, GL_AMBIENT, AmbColor
    invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, DiffColor
    mov eax, Radius
    invoke gluSphere, GlSphere, [eax], [eax+4], Parts, Parts
    mov eax, GlSphere
    ret
GlDrawSphere ENDP

GlDrawCone PROC     AmbColor    :DWORD,
                    DiffColor   :DWORD,
                    BaseRad     :DWORD,
                    Height      :DWORD,
                    Slices      :DWORD
    LOCAL GlCylinder: DWORD
    invoke gluNewQuadric
    mov GlCylinder, eax
    invoke gluQuadricDrawStyle, GlCylinder, GLU_FILL
    invoke gluQuadricNormals, GlCylinder, GLU_SMOOTH
    invoke glMaterialfv, GL_FRONT, GL_AMBIENT, AmbColor
    invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, DiffColor
    mov eax, BaseRad
    lea ebx, DValue0
    mov ecx, Height
    invoke gluCylinder, GlCylinder, [eax], [eax+4],
        [ebx], [ebx+4], [ecx], [ecx+4], Slices, Slices
    mov eax, GlCylinder
    ret
GlDrawCone ENDP

GenerateGlScale PROC ARRP :DWORD
    mov eax, ARRP
    mov ecx, [eax]
    mov ebx, [eax+4]
    mov eax, [eax+8]
    invoke glScalef, ecx, ebx, eax
    ret
GenerateGlScale ENDP

GenerateGlPos PROC ARRP :DWORD
    mov eax, ARRP
    mov ecx, [eax]
    mov ebx, [eax+4]
    mov eax, [eax+8]
    invoke glTranslatef, ecx, ebx, eax
    ret
GenerateGlPos ENDP

GenerateGlRotationX PROC RAD: DWORD
    invoke glRotatef, RAD, FValue1, FValue0, FValue0
    ret
GenerateGlRotationX ENDP

DrawPlayerPlane PROC    PlayerPosition :DWORD
    invoke glPushMatrix
      invoke GenerateGlPos, PlayerPosition
      invoke GenerateGlScale, ADDR PlayerMainScale
      invoke glMaterialfv, GL_FRONT, GL_AMBIENT, ADDR PlayerBodyAmbient
      invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, ADDR PlayerBodyDiffuse
      invoke GlDrawCube
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR PlayerLWingPos
        invoke GenerateGlScale, ADDR PlayerLWingScale
        invoke GlDrawCube
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR PlayerRWingPos
        invoke GenerateGlScale, ADDR PlayerRWingScale
        invoke GlDrawCube
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlRotationX, FValue90
        invoke GenerateGlPos, ADDR PlayerLGunPos
        invoke GenerateGlScale, ADDR PlayerLGunScale
        invoke GlDrawCylinder, ADDR PlayerGunAmb, ADDR PlayerGunDiff, 
            ADDR PlayerGunBaseRad, ADDR PlayerGunTopRad, 
            ADDR PlayerGunZPos, PlayerGunSlice,
            PlayerGunSlice
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlRotationX, FValue90
        invoke GenerateGlPos, ADDR PlayerRGunPos
        invoke GenerateGlScale, ADDR PlayerLGunScale
        invoke GlDrawCylinder, ADDR PlayerGunAmb, ADDR PlayerGunDiff,
            ADDR PlayerGunBaseRad, ADDR PlayerGunTopRad,
            ADDR PlayerGunZPos, PlayerGunSlice, PlayerGunSlice
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR PlayerHeadPos
        invoke GenerateGlScale, ADDR PlayerHeadScale
        invoke GlDrawSphere, ADDR PlayerTopAmb, ADDR PlayerTopDiff,
            ADDR DValue1, PlayerTopSlice 
      invoke glPopMatrix
    invoke glPopMatrix
    ret
DrawPlayerPlane ENDP 

DrawEnemyPlane PROC     EnemyPosition   :DWORD 
    invoke glPushMatrix
      invoke GenerateGlPos, EnemyPosition
      invoke GenerateGlScale, ADDR EnemyMainScale
      invoke glMaterialfv, GL_FRONT, GL_AMBIENT, ADDR EnemyBodyAmbient
      invoke glMaterialfv, GL_FRONT, GL_DIFFUSE, ADDR EnemyBodyDiffuse
      invoke GlDrawCube
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR EnemyLWingPos
        invoke GenerateGlScale, ADDR EnemyLWingScale
        invoke GlDrawCube
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR EnemyRWingPos
        invoke GenerateGlScale, ADDR EnemyRWingScale
        invoke GlDrawCube
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlRotationX, FValue90
        invoke GenerateGlPos, ADDR EnemyLGunPos
        invoke GenerateGlScale, ADDR EnemyLGunScale
        invoke GlDrawCylinder, ADDR EnemyGunAmb, ADDR EnemyGunDiff, 
            ADDR EnemyGunBaseRad, ADDR EnemyGunTopRad, 
            ADDR EnemyGunZPos, EnemyGunSlice,
            EnemyGunSlice
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlRotationX, FValue90
        invoke GenerateGlPos, ADDR EnemyRGunPos
        invoke GenerateGlScale, ADDR EnemyLGunScale
        invoke GlDrawCylinder, ADDR EnemyGunAmb, ADDR EnemyGunDiff,
            ADDR EnemyGunBaseRad, ADDR EnemyGunTopRad,
            ADDR EnemyGunZPos, EnemyGunSlice, EnemyGunSlice
      invoke glPopMatrix
      invoke glPushMatrix
        invoke GenerateGlPos, ADDR EnemyHeadPos
        invoke GenerateGlScale, ADDR EnemyHeadScale
        invoke GlDrawSphere, ADDR EnemyTopAmb, ADDR EnemyTopDiff,
            ADDR DValue1, EnemyTopSlice 
      invoke glPopMatrix
    invoke glPopMatrix
    ret
DrawEnemyPlane ENDP 

DrawEnemyBullet PROC   BulletPosition  :DWORD
    invoke glPushMatrix
      invoke GenerateGlPos, BulletPosition
      invoke GenerateGlScale, ADDR BulletScale
      invoke GenerateGlRotationX, FValue90
      invoke GlDrawCone, ADDR PlayerBulletAmb, ADDR PlayerBulletDiff,
                ADDR DValue1, ADDR DValue1, BulletSlices
    invoke glPopMatrix
    ret
DrawEnemyBullet ENDP

DrawPlayerBullet PROC   BulletPosition  :DWORD
    invoke glPushMatrix
      invoke GenerateGlPos, BulletPosition
      invoke GenerateGlScale, ADDR BulletScale
      invoke GenerateGlRotationX, FValueM90
      invoke GlDrawCone, ADDR EnemyBulletAmb, ADDR EnemyBulletDiff,
                ADDR DValue1, ADDR DValue1, BulletSlices
    invoke glPopMatrix
    ret
DrawPlayerBullet ENDP

remapXYToPos	PROC 	Position	:DWORD,
						OutPos		:DWORD,
						ZPos		:REAL4
	LOCAL 	@tmp:DWORD 
	mov		eax, Position
	mov 	ebx, eax
	; (x-minx)/(maxx-minx)*(nmaxx-nminx)+nminx
	; eax: Y, ebx, X
	and		eax, 0FFFFH
	shr 	ebx, 16
	mov		@tmp, ebx
	fild	@tmp
	xor		ecx, ecx
	mov		cx, _WIDTH
	sub		ecx, 1
	mov		@tmp, ecx
	fild	@tmp
	fdiv
	fld		CameraW
	fmul
	fld		CameraL
	fadd
	mov		ebx, OutPos
	fstp	DWORD PTR [ebx]
	
	mov		@tmp, eax
	fild	@tmp
	xor		ecx, ecx
	mov		cx, _HEIGHT
	sub		ecx, 1
	mov		@tmp, ecx
	fild	@tmp
	fdiv
	fld		CameraH
	fmul
	fld		CameraT
	fadd
	fstp	DWORD PTR [ebx+4]

	fld 	ZPos
	fstp	DWORD PTR [ebx+8]
	ret
remapXYToPos	ENDP

; render enemy bullets
renderEnemyBullet proc
	LOCAL 	@bb	:DWORD
	LOCAL	@bt	:DWORD
	LOCAL	@tp[3] :REAL4
	xor		ecx, ecx

	push 	enemyBulBtm
	pop		@bb		
	push 	enemyBulTop 
	pop		@bt
	mov		edi, @bb
	
 CPH_BE:
	cmp		edi, @bt
	je		CPH_EE
	mov		ebx, enemyBulList[edi*4]
	inc		edi
	mov		eax, enemyBulList[edi*4]
	inc 	edi 

	push	edi
	lea		ebx, @tp
	invoke	remapXYToPos, eax, ebx, BulletZPos
	invoke 	DrawEnemyBullet, ADDR @tp
	pop		edi

	cmp		edi, 2048
	jle		CPH_BE
	sub		edi, 2048
	jmp		CPH_BE

 CPH_EE:
	ret
renderEnemyBullet endp

; render player bullets
renderPlayerBullet proc
	LOCAL 	@bb	:DWORD
	LOCAL	@bt	:DWORD
	LOCAL	@tp[3] :REAL4
	xor		ecx, ecx

	push 	playerBulBtm
	pop		@bb		
	push 	playerBulTop
	pop		@bt
	mov		edi, @bb
	
 CPH_BP:
	cmp		edi, @bt
	je		CPH_EP
	mov		ebx, playerBulList[edi*4]
	inc		edi
	mov		eax, playerBulList[edi*4]
	inc 	edi 

	push 	edi
	lea		ebx, @tp
	invoke	remapXYToPos, eax, ebx, BulletZPos
	invoke 	DrawPlayerBullet, ADDR @tp
	pop 	edi

	cmp		edi, 2048
	jle		CPH_BP
	sub		edi, 2048
	jmp		CPH_BP

 CPH_EP:
	ret
renderPlayerBullet endp

; render enemy to screen buffer
renderEnemy proc
	LOCAL 	@bb	:DWORD
	LOCAL	@bt	:DWORD
	LOCAL	@tp[3] :REAL4
	xor		ecx, ecx

	push 	enemyBtm
	pop		@bb		
	push 	enemyTop
	pop		@bt
	mov		edi, @bb
	
 CPH_ES:
	cmp		edi, @bt
	je		CPH_EES
	lea		eax, enemyList[edi*4]
	mov		ebx, enemyList[edi*4]
	inc		edi
	mov		eax, enemyList[edi*4]
	inc 	edi 

	push	edi
	lea		ebx, @tp
	invoke	remapXYToPos, eax, ebx, EnemyZPos
	pop		edi
	push	edi
	invoke 	DrawEnemyPlane, ADDR @tp
	pop 	edi

	cmp		edi, 2048
	jle		CPH_ES
	sub		edi, 2048
	jmp		CPH_ES

 CPH_EES:
	ret
renderEnemy endp

; render player use playerX and palyerY
renderPlayer proc
	LOCAL	@tp[3] :REAL4
	mov		ax, playerX
	shl		eax, 16
	mov		ax, playerY

	lea		ebx, @tp
	invoke	remapXYToPos, eax,ebx, PlayerZPos
	invoke 	DrawPlayerPlane, ADDR @tp

	ret
renderPlayer endp

; ###########################################
; ####### this region is for gameplay #######
; ###########################################

; get buffer offset by position
; now abandoned?
getPos proc uses ebx, px:word, py :word
			mov		ax, _WIDTH
			cmp		px, ax
			jge		OBound
			mov		ax, _HEIGHT
			cmp		py, ax
			jge		OBound
			xor		eax, eax
			cmp		px, ax
			jle		OBound
			cmp		py, ax
			jle		OBound
			mov		bx, py
			mov		ax, _WIDTH
			mul		ebx
			add		ax, px
			ret
 OBound:		mov		eax, 0FFFFFFFFH
			ret
getPos endp

; move console cursor to (x,y)
; use for console debug
cursorXY proc uses eax, px :word, py:word
			local	handle :HANDLE
			local	pos :COORD
			mov		ax, px
			mov		pos.x, ax
			mov		ax, py
			mov		pos.y, ax
			invoke	GetStdHandle, STD_OUTPUT_HANDLE
			mov		handle, eax
			invoke	SetConsoleCursorPosition, handle, addr pos
			ret
cursorXY endp

; check whether obj at posA and obj at posB is collide
; use |ax-bx|+|ay-by| to check distance
; collide then turn eax to 1, else to 0
checkHitbox	proc uses ebx ecx, posA :dword, posB :dword
			xor		eax, eax
			mov		ebx, posA
			mov		ecx, posB
			; bigger one sub smaller one
			; lower 16 bit
			cmp		bx, cx
			jge		CHB1
			; else exchange
			push	ebx
			push	ecx
			pop		ebx
			pop		ecx
 CHB1:		sub		bx, cx
			; ax to add
			add		ax, bx
			; higher 16 bit
			shr		ebx, 16
			shr		ecx, 16
			cmp		bx, cx
			jge		CHB2
			push	ebx
			push	ecx
			pop		ebx
			pop		ecx
 CHB2:		sub		bx, cx
			add		ax, bx
			cmp		ax, 50
			; if hit
			jle		CHB3
			xor		eax, eax
			ret
 CHB3:		xor		eax, eax
			mov		eax, 1
			ret
checkHitbox endp

; check hit of all enemys, hit with playerbullet
checkEnemyHit proc uses eax ebx ecx edx
			local	enemyCopy :dword
			local	bulletCopy :dword
			local	@eb :dword
			local	@et :dword
			local	@bb :dword
			local	@bt :dword
			mov		edi, playerBulBtm
			mov		@bb, edi
			mov		edi, playerBulTop
			mov		@bt, edi
			mov		edi, enemyBtm
			mov		@eb, edi
			mov		edi, enemyTop
			mov		@et, edi
			mov		edi, @bb
			mov		esi, @eb
			; loop of iterate enemy
 CEH_E:		cmp		esi, 2048
			jl		CEH_3
			sub		esi, 2048
			; if bigger than 2048, sub 2048, equals to mod 2048
 CEH_3:		cmp		esi, @bt
			je		CEH_R
			mov		ecx, enemyList[esi*4]
			inc		esi
			mov		edx, enemyList[esi*4]
			inc		esi
			; loop of itetate playerbullet
 CEH_B:		mov		eax, playerBulList[edi*4]
			inc		edi
			mov		ebx, playerBulList[edi*4]
			inc		edi
			; compare pos dword
			invoke	checkHitbox, ebx, edx
			cmp		eax, 0
			je		CEH_1
			; not je CEH_1, means bullet and enemy collides
			mov		enemyCopy, ecx
			mov		bulletCopy, eax
			; only need lower 2 bit
			and		cx, 3
			; same color, doesn't hit
			cmp		cx, ax
			je		CEH_1
			; else hit
			mov		ecx, enemyCopy
			mov		ax, cx
			shr		ecx, 16
			sub		ecx, 50
			cmp		ecx, 1
			jle		CEH_Dead
			shl		ecx, 16
			mov		cx, ax
			jmp		CEH_C
 CEH_Dead:	
			xor		ecx, ecx
 CEH_C:
			; go back to point to current obj
			sub		edi, 2
			sub		esi, 2
			mov		enemyList[esi*4], ecx
			xor		eax, eax
			mov		playerBulList[edi*4], eax
			add		esi, 2
			add		edi, 2
			
 CEH_1:		cmp		edi, 2048
			jl		CEH_2
			sub		edi, 2048
 CEH_2:		
			cmp		edi, @et
			je		CEH_E
			jmp		CEH_B
 CEH_R:
			ret
checkEnemyHit endp

; check player's collide to enemy and enemy bullet
checkPlayerHit proc uses eax ebx ecx edx
			local	bulletCopy :dword
			local	enemyCopy :dword
			local	@eb :dword
			local	@et :dword
			local	@bb :dword
			local	@bt :dword
			; construct player pos dword use playerX and playerY, to ecx
			xor		ecx, ecx
			mov		cx, playerX
			shl		ecx, 16
			mov		cx, playerY

			mov		edi, enemyBulBtm
			mov		@bb, edi
			mov		edi, enemyBulTop
			mov		@bt, edi
			mov		esi, enemyBtm
			mov		@eb, esi
			mov		esi, enemyTop
			mov		@et, esi
			mov		edi, @bb
			mov		esi, @eb
			; loop to check enemy bullet hit
 CPH_B:		
			cmp		edi, @bt
			je		CPH_E
			mov		ebx, enemyBulList[edi*4]
			inc		edi
			mov		eax, enemyBulList[edi*4]
			inc		edi
			invoke	checkHitbox, eax, ecx
			cmp		eax, 0
			je		CPH_1
			; player hitted by bullet
			mov		bulletCopy, ebx
			; only need lower 2 bit
			and		bx, 3
			; same color, doesn't hit
			cmp		bx, playerColor
			je		CPH_1
			; else hit
			mov		bx, playerHP
			sub		bx, 50
			mov		playerHP, bx
			; go back to point to collide bullet
			sub		edi, 2
			xor		ebx, ebx
			mov		enemyBulList[edi*4], ebx
			add		edi, 2
 CPH_1:		
			cmp		edi, 2048
			jl		CPH_2
			sub		edi, 2048
 CPH_2:		
			jmp		CPH_B
			; loop to check enemy hit
 CPH_E:		
			cmp		esi, @et
			je		CPH_Ret
			mov		ebx, enemyList[esi*4]
			inc		esi
			mov		eax, enemyList[esi*4]
			inc		esi
			invoke	checkHitbox, eax, ecx
			cmp		eax, 0
			je		CPH_3
			; player hitted by enemy
			mov		enemyCopy, ebx
			; only need lower 2 bit
			and		bx, 3
			; same color, doesn't hit
			cmp		bx, playerColor
			je		CPH_3
			; else hit
			mov		bx, playerHP
			sub		bx, 50
			mov		playerHP, bx
			mov		ebx, enemyCopy
			mov		ax, bx
			shr		ebx, 16
			sub		ebx, 50
			cmp		ebx, 1
			jle		CPH_Dead
			shl		ebx, 16
			mov		bx, ax
			jmp		CPH_C
 CPH_Dead:	
			xor		ebx, ebx
 CPH_C:
			; go back to point to collide enemy
			sub		esi, 2
			mov		enemyList[esi*4], ebx
			add		esi, 2

 CPH_3:		cmp		edi, 2048
			jl		CPH_4
			sub		edi, 2048
 CPH_4:		
			jmp		CPH_E
 CPH_Ret:
			ret
checkPlayerHit endp

; add single bullet to enemy bullet list
; bullet: higher 32 bit of bullet, type
; pos: lower 32 bit of bullet, position
addEBullet proc uses eax edi, bullet :dword, pos :dword
			; change top
			mov		edi, enemyBulTop
			mov		eax, bullet
			mov		enemyBulList[edi*4], eax
			inc		edi
			mov		eax, pos
			mov		enemyBulList[edi*4], eax
			inc		edi
			; mod 2048
			cmp		edi, 2048
			jl		AEB
			sub		edi, 2048
 AEB:		mov		enemyBulTop, edi
			ret
addEBullet endp

; add single enemy to enemy list
; enemy: higher 32 bit of enemy, enemy type and hp(each for 8 bit)
; pos: lower 32 bit of enemy, position
addEnemy proc uses eax edi, enemy :dword, pos :dword
			mov		edi, enemyTop
			mov		eax, enemy
			mov		enemyList[edi*4], eax
			inc		edi
			mov		eax, pos
			mov		enemyList[edi*4], eax
			inc		edi
			cmp		edi, 2048
			jl		AEN
			sub		edi, 2048
 AEN:		mov		enemyTop, edi
			ret
addEnemy endp

; add to player bullet list, according to playerX, playerY, and playerColor
addPBullet proc	uses eax edi
			mov		edi, playerBulTop
			xor		eax, eax
			mov		ax, playerColor
			; shl		eax, 16
			mov		playerBulList[edi*4], eax
			inc		edi
			xor		eax, eax
			mov		ax, playerX
			shl		eax, 16
			mov		ax, playerY
			mov		playerBulList[edi*4], eax
			inc		edi
			cmp		edi, 2048
			jl		APB
			sub		edi, 2048
 APB:		
			mov		playerBulTop, edi
			ret
addPBullet endp

; randomly generate enemy bullet for each enemy
generateEBullet proc uses ebx ecx edi
			mov		edi, enemyBtm
 GEB:		
			cmp		edi, enemyTop
			je		GEBRet
			mov		ebx, enemyList[edi*4]
			inc		edi
			mov		ecx, enemyList[edi*4]
			inc		edi
			; save environment, rand to make p 1/3
			push	edi
			push	ebx
			push	ecx
			invoke	time, 0
			invoke	srand, eax
			invoke	rand
			mov		ebx, 3
			div		ebx
			pop		ecx
			pop		ebx
			pop		edi
			; rand%3 equal to 0, skip
			cmp		edx, 0
			jne		GEB3
			; get higher 16 bit, bullet type
			shr		ebx, 16
			; 1&3=1,5&3=1,2&3=2,6&3=2
			and		bx, 3
			; 1 to generate white bullet
			cmp		bx, 1
			je		GEBW
			; else generate black bullet
			invoke	addEBullet, 2, ecx
			jmp		GEB3
 GEBW:
			invoke	addEBullet, 1, ecx
 GEB3:
			cmp		edi, 2048
			jl		GEB2
			sub		edi, 2048
 GEB2:		
			jmp		GEB
 GEBRet:
			ret
generateEBullet endp

; randomly generate enemy
generateEnemy proc uses eax ebx ecx edx edi
			; possibility filter, 2/3
			invoke	time, 0
			invoke	srand, eax
			invoke	rand
			mov		ebx, 3
			div		ebx
			cmp		edx, 0
			je		GENR
			xor		ecx, ecx
			; 1 to generate white enemy
			cmp		edx, 1
			je		GEN1
			; 2 to black
			mov		cx, 100
			shl		ecx, 16
			; now hp is 100 default
			mov		cx, 2
			jmp		GEN2
 GEN1:		
			mov		cx, 100
			shl		ecx, 16
			mov		cx, 1
 GEN2:
			; rand position
			xor		eax, eax
			;mov		eax, 1
			invoke	time, 0
			invoke	srand, eax
			invoke	rand
			mov		bx, _WIDTH
			div		bx
			xor		eax, eax
			mov		ax, dx
			shl		eax, 16
			; default posY is 0
			invoke	addEnemy, ecx, eax
 GENR:
			ret
generateEnemy endp

; move all bullet
moveBullet proc uses eax ebx edx edi
			mov		edi, enemyBulBtm
 MVEB:		cmp		edi, enemyBulTop
			je		MVBC
			mov		eax, enemyBulList[edi*4]
			inc		edi
			mov		ebx, enemyBulList[edi*4]
			add		bx, 1
			cmp		bx, _HEIGHT
			jl		MB2
			xor		eax, eax
			dec		edi
			mov		enemyBulList[edi*4], eax
			inc		edi
 MB2:
			mov		enemyBulList[edi*4], ebx
			inc		edi

			cmp		edi, 2048
			jl		MB1
			sub		edi, 2048
 MB1:
			jmp		MVEB
 MVBC:
			mov		edi, playerBulBtm
 MVPB:
			cmp		edi, playerBulTop
			je		MVBRet
			mov		eax, playerBulList[edi*4]
			inc		edi
			mov		ebx, playerBulList[edi*4]
			sub		bx, 1
			cmp		bx, 1
			jg		MB4
			xor		eax, eax
			dec		edi
			mov		playerBulList[edi*4], eax
			inc		edi
 MB4:
			mov		playerBulList[edi*4], ebx
			inc		edi

			cmp		edi, 2048
			jl		MB3
			sub		edi, 2048
 MB3:
			jmp		MVPB
 MVBRet:		
			ret
moveBullet endp

; move of all enemy
moveEnemy proc uses eax ebx ecx edx edi
			mov		edi, enemyBtm
 MEN:		
			cmp		edi, enemyTop
			je		MENRet
			; enemy type is useless, skip
			inc		edi
			; enemy pos to ecx
			mov		ecx, enemyList[edi*4]
			; bx for higher 16 bit, pos x
			mov		ebx, ecx
			shr		ebx, 16
			; rand to make it randomly move left, right or down
			push	ecx
			push	ebx
			push	edi
			invoke	time, 0
			invoke	srand, eax
			invoke	rand
			pop		edi
			pop		ebx
			pop		ecx
			mov		eax, 0
			mov		edx, 3
			div		dl
			; 0, goto vertical
			cmp		dx, 0
			je		MENV
			; 1 goto left
			cmp		dx, 1
			je		MENL
			; else goto right
			add		bx, 1
			; overbound, delete
			cmp		bx, _WIDTH
			jge		MENDel
			; move higher 16 bit back to ecx
			shl		ebx, 16
			mov		bx, cx
			mov		ecx, ebx
			jmp		MENV
 MENL:		dec		bx
			cmp		bx, 0
			jle		MENDel
			shl		ebx, 16
			mov		bx, cx
			mov		ecx, ebx
			; default move 1 down
 MENV:		inc		ecx
			cmp		cx, _HEIGHT
			jge		MENDel
			cmp		cx, 0
			jle		MENDel
			jmp		MENRem
 MENDel:		dec		edi
			; 0 to delete enemy
			mov		ecx, 0
			mov		enemyList[edi*4], ecx
			inc		edi
			jmp		MEN2
 MENRem:		; else refresh enemy pos, lower 32 bit
			mov		enemyList[edi*4], ecx
			
 MEN2:		inc		edi
			cmp		edi, 2048
			jl		MEN1
			sub		edi, 2048
 MEN1:		
			jmp		MEN
 MENRet:
			ret
moveEnemy endp

; player's move during frames by pVertical and pHorizonal
movePlayer proc uses eax
			xor		eax, eax
			mov		ax, pVertical
			cmp		ax, 2
			je		PMF
			cmp		ax, 1
			je		PMB
			jmp		PMH
 PMF:		mov		ax, playerY
			cmp		ax, 0
			jle		PMH
			dec		ax
			mov		playerY, ax
			jmp		PMH
 PMB:		mov		ax, playerY
			cmp		ax, _HEIGHT
			jge		PMH
			inc		ax
			mov		playerY, ax
			jmp		PMH
 PMH:		mov		ax, pHorizonal
			cmp		ax, 2
			je		PML
			cmp		ax, 1
			je		PMR
			jmp		PRet
 PML:		mov		ax, playerX
			cmp		ax, 0
			jle		PRet
			dec		ax
			mov		playerX, ax
			jmp		PRet
 PMR:		mov		ax, playerX
			cmp		ax, _WIDTH
			jge		PRet
			inc		ax
			mov		playerX, ax
			jmp		PRet
 PRet:		
			ret
movePlayer endp

; change player's current color to another one
playerChange proc uses eax
			mov		ax, playerColor
			xor		ax, 1
			mov		playerColor, ax
			ret
playerChange endp

; shoot bullet, have restriction
; each shoot at most 3 bullet, until resetLock
playerShoot proc uses eax ebx ecx edx edi esi
			mov		ax, bulletRes
			cmp		ax, 0
			jle		ShtRet
			dec		ax
			mov		bulletRes, ax
			call	addPBullet
ShtRet:		ret
playerShoot endp

; read keyboard state
readOpr proc uses eax ebx
			local	msg : MSG
 LoopR:		xor		eax, eax
			mov		pVertical, ax
			mov		pHorizonal, ax
			mov		al, 'A'
			invoke	GetKeyState, al
			and		ax, 08000H
			je		readA
			mov		ax, 2
			mov		pHorizonal, ax
 readA:		mov		al, 'D'
			invoke	GetKeyState, al
			and		ax, 08000H
			cmp		ax, 0
			je		readD
			mov		ax, pHorizonal
			shr		ax, 1
			xor		ax, 1
			mov		pHorizonal, ax
 readD:		mov		al, 'W'
			invoke	GetKeyState, al
			and		ax, 08000H
			cmp		ax, 0
			je		readW
			mov		ax, 2
			mov		pVertical, ax
 readW:		mov		al, 'S'
			invoke	GetKeyState, al
			and		ax, 08000H
			cmp		ax, 0
			je		readS
			mov		ax, pVertical
			shr		ax, 1
			xor		ax, 1
			mov		pVertical, ax
 readS:		mov		al, 'J'
			invoke	GetKeyState, al
			and		ax, 08000H
			cmp		ax, 0
			je		RORet
			mov		ax, playerY
			cmp		ax, 0
			jle		RORet
			mov		bx, playerX
			invoke	playerShoot
 readJ:
			; TODO: press K to change state
			;invoke	GetMessage, addr msg, NULL, 0, 0
			;invoke	DispatchMessage, addr msg
			;mov		eax, msg.wParam
			;invoke	printf, offset FMTCHAR, "a"
			;cmp		eax, "K"
			;je		PChg
			;cmp		eax, "k"
			;je		PChg
			;jmp		RORet
 ;PChg:		call	playerChange
 RORet:		;jmp		LoopR
			ret
readOpr endp

; lock restricts the bullets and moves player can perform during each frame
; when frame refresh, lock should be reset
resetLock proc
			mov		bulletRes, 3
			mov		moveRes, 3
			ret
resetLock endp

; #################################################
; ##### this region is for main loop and init #####
; #################################################

; initialize the game

initGame proc
			mov		ax, 1000
			mov		playerHP, ax
			xor		eax, eax
			mov		ax, INIT_X
			mov		playerX, ax
			mov		ax, INIT_Y
			mov		playerY, ax
			call	GlInit
			ret
initGame endp

MainCallback    PROC hWin:DWORD,
                 uMsg:DWORD,
                 wParam:DWORD,
                 lParam:DWORD
    LOCAL WinRect: RECT
    LOCAL PixFormat: DWORD
    .if uMsg == WM_COMMAND
        .if wParam == 1000
            invoke SendMessage, hWin, WM_SYSCOMMAND, SC_CLOSE, NULL
        .endif
        mov eax, 0
        ret
    .elseif uMsg == WM_CREATE
        ; init the HDC
        invoke GetDC, hWin
        mov MainHDC, eax
        mov ax, sizeof PixFrm
        mov PixFrm.nSize, ax
        mov PixFrm.nVersion, 1
        mov PixFrm.dwFlags, PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL or PFD_DOUBLEBUFFER
        mov PixFrm.iPixelType, PFD_TYPE_RGBA
        mov PixFrm.cColorBits, 8
        mov PixFrm.cDepthBits, 32
        mov PixFrm.cAccumBits, 0
        mov PixFrm.iLayerType, PFD_MAIN_PLANE
        invoke ChoosePixelFormat, MainHDC, ADDR PixFrm
        mov PixFormat, eax
        invoke SetPixelFormat, MainHDC, PixFormat, ADDR PixFrm
        or  eax, eax
        jz  NoPix
        invoke wglCreateContext, MainHDC
        mov OpenDC, eax
        invoke wglMakeCurrent, MainHDC, OpenDC
        invoke GlInit
      NoPix:
        mov eax, 0
        ret
    .elseif uMsg == WM_SIZE
        invoke GetClientRect, hWin, ADDR WinRect
        invoke ResizeObject, WinRect.right, WinRect.bottom
        mov eax, 0
        ret
    .elseif uMsg == WM_CLOSE
        invoke MessageBox, hWin, ADDR szCloseHint, ADDR szWindowTitle, MB_YESNO + MB_ICONQUESTION
        .if eax == IDNO
            mov eax, 0
            ret
        .endif
        mov	eax,OpenDC
		or	eax,eax
		jz	NoGlDC
        invoke wglDeleteContext,OpenDC
      NoGlDC:
        invoke ReleaseDC,hWin,MainHDC
        invoke DestroyWindow, hWin
        mov eax, 0
        ret
    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, NULL
        mov eax, 0
        ret
    .endif
    invoke DefWindowProc, hWin, uMsg, wParam, lParam
    ret
MainCallback    ENDP

; render all the visible object
showScreen proc
	; render each object per frame is not a good idea?
	; maybe we need to render init obj, then move them or delete them
	; you're right, and delete it may be worse because release cost much
	; the best way is to maintain a pool, which play a role as an customized allocator
	; but I'm too lazy to do it.
	; so I choose to keep them, and wait for the overflow.
	; god bless us.
	invoke glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
    invoke glPushMatrix
		invoke renderPlayer
		invoke renderEnemy
		invoke renderPlayerBullet
		invoke renderEnemyBullet
    invoke glPopMatrix
    invoke SwapBuffers, MainHDC
	ret
showScreen endp

; called when player's dead
gameOver proc
			invoke		printf, offset GAMEOVER
			ret
gameOver endp

startMenu proc
			ret
startMenu endp

pauseMenu proc
			ret
pauseMenu endp

MainLoop PROC 
			LOCAL   msg: MSG
			local	frameCount :word
 BeginLoop:
    		invoke PeekMessage, ADDR msg, 0, 0, 0, PM_NOREMOVE
    		or      eax, eax
    		jz      NoMsg
    		invoke GetMessage, ADDR msg, NULL, 0, 0
    		or      eax, eax
    		jz      EndLoop
    		invoke TranslateMessage, ADDR msg
    		invoke DispatchMessage, ADDR msg
    		jmp     BeginLoop   
 NoMsg: 		
 		; update loop
			; sleep frame time
			mov		bx, frameCount
			inc		bx
			mov		frameCount, bx
			cmp		bx, 200
			jge		GL1000
			mov		ax, bx
			mov		dl, 100
			div		dl
			cmp		ah, 0
			je		GL500
			mov		ax, bx
			mov		dl, 50
			div		dl
			cmp		ah, 0
			je		GL250
			mov		ax, bx
			mov		dl, 20
			div		dl
			cmp		ah, 0
			je		GL100
			mov		ax, bx
			mov		dl, 10
			div		dl
			cmp		ah, 0
			je		GL50
			mov		ax, bx
			mov		dl, 5
			div		dl
			cmp		ah, 0
			je		GL25
			mov		ax, bx
			mov		dl, 2
			div		dl
			cmp		ah, 0
			je		GL10
			jmp		GL5
 GL1000:	; per 1 second
			mov		bx, 0
			mov		frameCount, bx
			call	generateEnemy
			;invoke	printf, offset FMTINT, 1

 GL500:		; per 500 ms
			
			
			;invoke	printf, offset FMTINT, 2
 GL250:		; per 250 ms
			call	resetLock
			
			
			;invoke	printf, offset FMTINT, 3
 GL100:		; per 100 ms
			call	generateEBullet
			
			;invoke	printf, offset FMTINT, 4

 GL50:		; per 50 ms
			
			
 GL25:		; per 25ms
			call	moveEnemy
			call	checkEnemyHit
			call	checkPlayerHit
			call	readOpr
 GL10:		; per 10ms
			call	movePlayer
 GL5:		; per 5ms
			call	moveBullet
			call	showScreen
			mov		dx, playerHP
			cmp		dx, 0
			jle		GameOvr
			; sleep 5ms to make fps around 200
			invoke	Sleep, 5
			jmp		BeginLoop
 GameOvr:	call	gameOver
 EndLoop:
   			mov     eax, msg.wParam
			ret
MainLoop ENDP

MainProg    PROC hInst: DWORD,
                 CmdLine: DWORD
    LOCAL   wc: WNDCLASSEX
    LOCAL   Wwd: DWORD
    LOCAL   Wht: DWORD
    LOCAL   Wtx: DWORD
    LOCAL   Wty: DWORD
    ; register the class
    mov     wc.cbSize, sizeof WNDCLASSEX
    mov     wc.style, 0
    mov     wc.lpfnWndProc, offset MainCallback
    mov     wc.cbClsExtra, NULL
    mov     wc.cbWndExtra, NULL
    push    hInst
    pop     wc.hInstance
    mov     wc.hbrBackground, COLOR_WINDOWTEXT + 1
    mov     wc.lpszMenuName, NULL
    mov     wc.lpszClassName, offset szClassName
    invoke LoadIcon, hInst, 2
    mov     wc.hIcon, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov     wc.hCursor, eax
    mov     wc.hIconSm, 0
    invoke RegisterClassEx, ADDR wc

    ; adjust the position
    mov     Wwd, 600
    mov     Wht, 800
    
    invoke GetSystemMetrics, SM_CXSCREEN
    shr     eax, 1
    mov     ebx, Wwd
    shr     ebx, 1
    sub     eax, ebx
    mov     Wtx, eax

    invoke GetSystemMetrics, SM_CYSCREEN
    shr     eax, 1
    mov     ebx, Wht
    shr     ebx, 1
    sub     eax, ebx
    mov     Wty, eax

    ; create the window

    invoke CreateWindowEx, 0, ADDR szClassName, ADDR szWindowTitle, WS_OVERLAPPEDWINDOW, Wtx, Wty, Wwd, Wht, NULL, NULL, hInst, NULL

    ; show the window

    mov     hWnd, eax
    invoke LoadMenu, hInst, 600
    invoke SetMenu, hWnd, eax
    invoke ShowWindow, hWnd, SW_SHOW
    invoke UpdateWindow, hWnd

    invoke MainLoop

    ret 

MainProg ENDP

main proc
			local	frameCount :word
			mov		ax, 0
			mov		frameCount, ax
			call	initGame

			invoke GetModuleHandle, NULL
    		mov     hInstance, eax
    		invoke GetCommandLine
    		mov     CommandLine, eax

			invoke MainProg, hInstance, CommandLine
			ret
main endp
end main