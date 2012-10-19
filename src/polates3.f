C-----------------------------------------------------------------------
      SUBROUTINE POLATES3(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
     &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
C$$$  SUBPROGRAM DOCUMENTATION BLOCK
C
C SUBPROGRAM:  POLATES3   INTERPOLATE SCALAR FIELDS (BUDGET)
C   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
C
C ABSTRACT: THIS SUBPROGRAM PERFORMS BUDGET INTERPOLATION
C           FROM ANY GRID TO ANY GRID FOR SCALAR FIELDS.
C           IT MAY BE RUN FOR A WHOLE (KGDSO(1)>=0) OR A SUBSECTION 
C           OF AN OUTPUT GRID (SUBTRACT KGDSO(1) FROM 255 AND
C           PASS IN THE LAT/LONS OF EACH POINT).
C           THE ALGORITHM SIMPLY COMPUTES (WEIGHTED) AVERAGES
C           OF BILINEARLY INTERPOLATED POINTS ARRANGED IN A SQUARE BOX
C           CENTERED AROUND EACH OUTPUT GRID POINT AND STRETCHING
C           NEARLY HALFWAY TO EACH OF THE NEIGHBORING GRID POINTS.
C           OPTIONS ALLOW CHOICES OF NUMBER OF POINTS IN EACH RADIUS
C           FROM THE CENTER POINT (IPOPT(1)) WHICH DEFAULTS TO 2
C           (IF IPOPT(1)=-1) MEANING THAT 25 POINTS WILL BE AVERAGED;
C           FURTHER OPTIONS ARE THE RESPECTIVE WEIGHTS FOR THE RADIUS
C           POINTS STARTING AT THE CENTER POINT (IPOPT(2:2+IPOPT(1))
C           WHICH DEFAULTS TO ALL 1 (IF IPOPT(1)=-1 OR IPOPT(2)=-1).
C           A SPECIAL INTERPOLATION IS DONE IF IPOPT(2)=-2.
C           IN THIS CASE, THE BOXES STRETCH NEARLY ALL THE WAY TO
C           EACH OF THE NEIGHBORING GRID POINTS AND THE WEIGHTS
C           ARE THE ADJOINT OF THE BILINEAR INTERPOLATION WEIGHTS.
C           THIS CASE GIVES QUASI-SECOND-ORDER BUDGET INTERPOLATION.
C           ANOTHER OPTION IS THE MINIMUM PERCENTAGE FOR MASK,
C           I.E. PERCENT VALID INPUT DATA REQUIRED TO MAKE OUTPUT DATA,
C           (IPOPT(3+IPOPT(1)) WHICH DEFAULTS TO 50 (IF -1).
C           IN CASES WHERE THERE IS NO OR INSUFFICIENT VALID INPUT DATA,
C           THE USER MAY CHOOSE TO SEARCH FOR THE NEAREST VALID DATA. 
C           THIS IS INVOKED BY SETTING IPOPT(20) TO THE WIDTH OF 
C           THE SEARCH SQUARE. THE DEFAULT IS 1 (NO SEARCH).  SQUARES ARE
C           SEARCHED FOR VALID DATA IN A SPIRAL PATTERN
C           STARTING FROM THE CENTER.  NO SEARCHING IS DONE WHERE
C           THE OUTPUT GRID IS OUTSIDE THE INPUT GRID.
C           ONLY HORIZONTAL INTERPOLATION IS PERFORMED.
C           THE GRIDS ARE DEFINED BY THEIR GRID DESCRIPTION SECTIONS
C           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63).
C           THE CURRENT CODE RECOGNIZES THE FOLLOWING PROJECTIONS:
C             (KGDS(1)=000) EQUIDISTANT CYLINDRICAL
C             (KGDS(1)=001) MERCATOR CYLINDRICAL
C             (KGDS(1)=003) LAMBERT CONFORMAL CONICAL
C             (KGDS(1)=004) GAUSSIAN CYLINDRICAL (SPECTRAL NATIVE)
C             (KGDS(1)=005) POLAR STEREOGRAPHIC AZIMUTHAL
C             (KGDS(1)=202) ROTATED EQUIDISTANT CYLINDRICAL (ETA NATIVE)
C           WHERE KGDS COULD BE EITHER INPUT KGDSI OR OUTPUT KGDSO.
C           AS AN ADDED BONUS (KGDSO(1)>=0) THE NUMBER OF OUTPUT
C           GRID POINTS AND THEIR LATITUDES AND LONGITUDES 
C           ARE ALSO RETURNED.  INPUT BITMAPS WILL BE INTERPOLATED
C           TO OUTPUT BITMAPS. OUTPUT BITMAPS WILL ALSO BE
C           CREATED WHEN THE OUTPUT GRID
C           EXTENDS OUTSIDE OF THE DOMAIN OF THE INPUT GRID.
C           THE OUTPUT FIELD IS SET TO 0 WHERE THE OUTPUT BITMAP IS OFF.
C        
C PROGRAM HISTORY LOG:
C   96-04-10  IREDELL
C 1999-04-08  IREDELL  SPLIT IJKGDS INTO TWO PIECES
C 1999-04-08  IREDELL  ADDED BILINEAR OPTION IPOPT(2)=-2
C 2001-06-18  IREDELL  INCLUDE MINIMUM MASK PERCENTAGE OPTION
C 2006-01-04  GAYNO    ADDED OPTION TO DO SUBSECTION OF OUTPUT GRID.
C                      ADDED SPIRAL SEARCH OPTION.
C
C USAGE:    CALL POLATES3(IPOPT,KGDSI,KGDSO,MI,MO,KM,IBI,LI,GI,
C    &                    NO,RLAT,RLON,IBO,LO,GO,IRET)
C
C   INPUT ARGUMENT LIST:
C     IPOPT    - INTEGER (20) INTERPOLATION OPTIONS
C                IPOPT(1) IS NUMBER OF RADIUS POINTS
C                (DEFAULTS TO 2 IF IPOPT(1)=-1);
C                IPOPT(2:2+IPOPT(1)) ARE RESPECTIVE WEIGHTS
C                (DEFAULTS TO ALL 1 IF IPOPT(1)=-1 OR IPOPT(2)=-1).
C                IPOPT(3+IPOPT(1)) IS MINIMUM PERCENTAGE FOR MASK
C                (DEFAULTS TO 50 IF IPOPT(3+IPOPT(1)=-1)
C     KGDSI    - INTEGER (200) INPUT GDS PARAMETERS AS DECODED BY W3FI63
C     KGDSO    - INTEGER (200) OUTPUT GDS PARAMETERS
C     MI       - INTEGER SKIP NUMBER BETWEEN INPUT GRID FIELDS IF KM>1
C                OR DIMENSION OF INPUT GRID FIELDS IF KM=1
C     MO       - INTEGER SKIP NUMBER BETWEEN OUTPUT GRID FIELDS IF KM>1
C                OR DIMENSION OF OUTPUT GRID FIELDS IF KM=1
C     KM       - INTEGER NUMBER OF FIELDS TO INTERPOLATE
C     IBI      - INTEGER (KM) INPUT BITMAP FLAGS
C     LI       - LOGICAL*1 (MI,KM) INPUT BITMAPS (IF SOME IBI(K)=1)
C     GI       - REAL (MI,KM) INPUT FIELDS TO INTERPOLATE
C
C   OUTPUT ARGUMENT LIST:
C     NO       - INTEGER NUMBER OF OUTPUT POINTS
C     RLAT     - REAL (MO) OUTPUT LATITUDES IN DEGREES
C     RLON     - REAL (MO) OUTPUT LONGITUDES IN DEGREES
C     IBO      - INTEGER (KM) OUTPUT BITMAP FLAGS
C     LO       - LOGICAL*1 (MO,KM) OUTPUT BITMAPS (ALWAYS OUTPUT)
C     GO       - REAL (MO,KM) OUTPUT FIELDS INTERPOLATED
C     IRET     - INTEGER RETURN CODE
C                0    SUCCESSFUL INTERPOLATION
C                2    UNRECOGNIZED INPUT GRID OR NO GRID OVERLAP
C                3    UNRECOGNIZED OUTPUT GRID
C                32   INVALID BUDGET METHOD PARAMETERS
C
C SUBPROGRAMS CALLED:
C   GDSWIZ       GRID DESCRIPTION SECTION WIZARD
C   IJKGDS0      SET UP PARAMETERS FOR IJKGDS1
C   (IJKGDS1)    RETURN FIELD POSITION FOR A GIVEN GRID POINT
C   POLFIXS      MAKE MULTIPLE POLE SCALAR VALUES CONSISTENT
C
C ATTRIBUTES:
C   LANGUAGE: FORTRAN 77
C
C$$$
CFPP$ EXPAND(IJKGDS1)
      IMPLICIT NONE
C
      INTEGER,    INTENT(IN   ) :: IBI(KM), IPOPT(20), KGDSI(200)
      INTEGER,    INTENT(IN   ) :: KM, MI, MO
      INTEGER,    INTENT(INOUT) :: KGDSO(200)
      INTEGER,    INTENT(  OUT) :: IBO(KM), IRET, NO
C
      LOGICAL*1,  INTENT(IN   ) :: LI(MI,KM)
      LOGICAL*1,  INTENT(  OUT) :: LO(MO,KM)
C
      REAL,       INTENT(IN   ) :: GI(MI,KM)
      REAL,       INTENT(  OUT) :: GO(MO,KM), RLAT(MO), RLON(MO)
C
      REAL,       PARAMETER     :: FILL=-9999.
C
      INTEGER                   :: IJKGDS1, I1, J1, I2, J2, IB, JB
      INTEGER                   :: IJKGDSA(20), IX, JX, IXS, JXS
      INTEGER                   :: K, KXS, KXT
      INTEGER                   :: LB, LSW, MP, MSPIRAL, MX
      INTEGER                   :: N, NB, NB1, NB2, NB3, NB4, NV, NX
      INTEGER                   :: N11(MO),N21(MO),N12(MO),N22(MO)
C
      REAL,    ALLOCATABLE      :: DUM1(:),DUM2(:)
      REAL                      :: GB, LAT(1), LON(1)
      REAL                      :: PMP, RB2, RLOB(MO), RLAB(MO), WB
      REAL                      :: W11(MO), W21(MO), W12(MO), W22(MO)
      REAL                      :: WO(MO,KM), XF, YF, XI, YI, XX, YY
      REAL                      :: XPTS(MO),YPTS(MO),XPTB(MO),YPTB(MO)
      REAL                      :: XXX(1), YYY(1)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE NUMBER OF OUTPUT POINTS AND THEIR LATITUDES AND LONGITUDES.
C  DO SUBSECTION OF GRID IF KGDSO(1) IS SUBTRACTED FROM 255.
      IRET=0
      IF(KGDSO(1).GE.0) THEN
        ALLOCATE(DUM1(MO))
        ALLOCATE(DUM2(MO))
        CALL GDSWIZ(KGDSO, 0,MO,FILL,XPTS,YPTS,RLON,RLAT,NO,0,
     &              DUM1,DUM2)
        DEALLOCATE(DUM1,DUM2)
        IF(NO.EQ.0) IRET=3
      ELSE
        KGDSO(1)=255+KGDSO(1)
        ALLOCATE(DUM1(MO))
        ALLOCATE(DUM2(MO))
        CALL GDSWIZ(KGDSO,-1,MO,FILL,XPTS,YPTS,RLON,RLAT,NO,0,
     &              DUM1,DUM2)
        DEALLOCATE(DUM1,DUM2)
        IF(NO.EQ.0) IRET=3
      ENDIF
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  SET PARAMETERS
      IF(IPOPT(1).GT.16) IRET=32  
      MSPIRAL=MAX(IPOPT(20),1)
      NB1=IPOPT(1)
      IF(NB1.EQ.-1) NB1=2
      IF(IRET.EQ.0.AND.NB1.LT.0) IRET=32
      LSW=1
      IF(IPOPT(2).EQ.-2) LSW=2
      IF(IPOPT(1).EQ.-1.OR.IPOPT(2).EQ.-1) LSW=0
      IF(IRET.EQ.0.AND.LSW.EQ.1.AND.NB1.GT.15) IRET=32
      MP=IPOPT(3+IPOPT(1))
      IF(MP.EQ.-1.OR.MP.EQ.0) MP=50
      IF(MP.LT.0.OR.MP.GT.100) IRET=32
      PMP=MP*0.01
      IF(IRET.EQ.0) THEN
        NB2=2*NB1+1
        RB2=1./NB2
        NB3=NB2*NB2
        NB4=NB3
        IF(LSW.EQ.2) THEN
          RB2=1./(NB1+1)
          NB4=(NB1+1)**4
        ELSEIF(LSW.EQ.1) THEN
          NB4=IPOPT(2)
          DO IB=1,NB1
            NB4=NB4+8*IB*IPOPT(2+IB)
          ENDDO
        ENDIF
      ELSE
        NB3=0
        NB4=1
      ENDIF
CMIC$ DO ALL AUTOSCOPE
      DO K=1,KM
        DO N=1,NO
          GO(N,K)=0.
          WO(N,K)=0.
        ENDDO
      ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  LOOP OVER SAMPLE POINTS IN OUTPUT GRID BOX
      CALL IJKGDS0(KGDSI,IJKGDSA)
      DO NB=1,NB3
C  LOCATE INPUT POINTS AND COMPUTE THEIR WEIGHTS
        JB=(NB-1)/NB2-NB1
        IB=NB-(JB+NB1)*NB2-NB1-1
        LB=MAX(ABS(IB),ABS(JB))
        WB=1
        IF(LSW.EQ.2) THEN
          WB=(NB1+1-ABS(IB))*(NB1+1-ABS(JB))
        ELSEIF(LSW.EQ.1) THEN
          WB=IPOPT(2+LB)
        ENDIF
        IF(WB.NE.0) THEN
          DO N=1,NO
            XPTB(N)=XPTS(N)+IB*RB2
            YPTB(N)=YPTS(N)+JB*RB2
          ENDDO
          ALLOCATE(DUM1(NO))
          ALLOCATE(DUM2(NO))
          CALL GDSWIZ(KGDSO, 1,NO,FILL,XPTB,YPTB,RLOB,RLAB,NV,0,
     &                DUM1,DUM2)
          CALL GDSWIZ(KGDSI,-1,NO,FILL,XPTB,YPTB,RLOB,RLAB,NV,0,
     &                DUM1,DUM2)
          DEALLOCATE(DUM1,DUM2)
          IF(IRET.EQ.0.AND.NV.EQ.0.AND.LB.EQ.0) IRET=2
          DO N=1,NO
            XI=XPTB(N)
            YI=YPTB(N)
            IF(XI.NE.FILL.AND.YI.NE.FILL) THEN
              I1=XI
              I2=I1+1
              J1=YI
              J2=J1+1
              XF=XI-I1
              YF=YI-J1
              N11(N)=IJKGDS1(I1,J1,IJKGDSA)
              N21(N)=IJKGDS1(I2,J1,IJKGDSA)
              N12(N)=IJKGDS1(I1,J2,IJKGDSA)
              N22(N)=IJKGDS1(I2,J2,IJKGDSA)
              IF(MIN(N11(N),N21(N),N12(N),N22(N)).GT.0) THEN
                W11(N)=(1-XF)*(1-YF)
                W21(N)=XF*(1-YF)
                W12(N)=(1-XF)*YF
                W22(N)=XF*YF
              ELSE
                N11(N)=0
                N21(N)=0
                N12(N)=0
                N22(N)=0
              ENDIF
            ELSE
              N11(N)=0
              N21(N)=0
              N12(N)=0
              N22(N)=0
            ENDIF
          ENDDO
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  INTERPOLATE WITH OR WITHOUT BITMAPS
CMIC$ DO ALL AUTOSCOPE
          DO K=1,KM
            DO N=1,NO
              IF(N11(N).GT.0) THEN
                IF(IBI(K).EQ.0) THEN
                  GB=W11(N)*GI(N11(N),K)+W21(N)*GI(N21(N),K)
     &              +W12(N)*GI(N12(N),K)+W22(N)*GI(N22(N),K)
                  GO(N,K)=GO(N,K)+WB*GB
                  WO(N,K)=WO(N,K)+WB
                ELSE
                  IF(LI(N11(N),K)) THEN
                    GO(N,K)=GO(N,K)+WB*W11(N)*GI(N11(N),K)
                    WO(N,K)=WO(N,K)+WB*W11(N)
                  ENDIF
                  IF(LI(N21(N),K)) THEN
                    GO(N,K)=GO(N,K)+WB*W21(N)*GI(N21(N),K)
                    WO(N,K)=WO(N,K)+WB*W21(N)
                  ENDIF
                  IF(LI(N12(N),K)) THEN
                    GO(N,K)=GO(N,K)+WB*W12(N)*GI(N12(N),K)
                    WO(N,K)=WO(N,K)+WB*W12(N)
                  ENDIF
                  IF(LI(N22(N),K)) THEN
                    GO(N,K)=GO(N,K)+WB*W22(N)*GI(N22(N),K)
                    WO(N,K)=WO(N,K)+WB*W22(N)
                  ENDIF
                ENDIF
              ENDIF
            ENDDO
          ENDDO
        ENDIF
      ENDDO   ! sub-grid points
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C  COMPUTE OUTPUT BITMAPS AND FIELDS
CMIC$ DO ALL AUTOSCOPE
      KM_LOOP : DO K=1,KM
        IBO(K)=IBI(K)
        N_LOOP : DO N=1,NO
          LO(N,K)=WO(N,K).GE.PMP*NB4
          IF(LO(N,K)) THEN
            GO(N,K)=GO(N,K)/WO(N,K)
          ELSEIF (MSPIRAL.GT.1) THEN
            ALLOCATE(DUM1(1))
            ALLOCATE(DUM2(1))
            LAT(1)=RLAT(N)
            LON(1)=RLON(N)
            CALL GDSWIZ(KGDSI,-1,1,FILL,XXX,YYY,LON,LAT,NV,0,
     &                  DUM1,DUM2)
            DEALLOCATE(DUM1,DUM2)
            XX=XXX(1)
            YY=YYY(1)
            IF (NV.EQ.1)THEN
              I1=NINT(XX)
              J1=NINT(YY)
              IXS=SIGN(1.,XX-I1)
              JXS=SIGN(1.,YY-J1)
              SPIRAL_LOOP : DO MX=2,MSPIRAL**2
                KXS=SQRT(4*MX-2.5)
                KXT=MX-(KXS**2/4+1)
                SELECT CASE(MOD(KXS,4))
                CASE(1)
                  IX=I1-IXS*(KXS/4-KXT)
                  JX=J1-JXS*KXS/4
                CASE(2)
                  IX=I1+IXS*(1+KXS/4)
                  JX=J1-JXS*(KXS/4-KXT)
                CASE(3)
                  IX=I1+IXS*(1+KXS/4-KXT)
                  JX=J1+JXS*(1+KXS/4)
                CASE DEFAULT
                  IX=I1-IXS*KXS/4
                  JX=J1+JXS*(KXS/4-KXT)
                END SELECT
                NX=IJKGDS1(IX,JX,IJKGDSA)
                IF(NX.GT.0.)THEN
                  IF(LI(NX,K).OR.IBI(K).EQ.0) THEN
                    GO(N,K)=GI(NX,K)
                    LO(N,K)=.TRUE.
                    CYCLE N_LOOP
                  ENDIF
                ENDIF
              ENDDO SPIRAL_LOOP
              IBO(K)=1
              GO(N,K)=0.
            ELSE
              IBO(K)=1
              GO(N,K)=0.
            ENDIF
          ELSE  ! no spiral search option
            IBO(K)=1
            GO(N,K)=0.
          ENDIF
        ENDDO N_LOOP
      ENDDO KM_LOOP
      IF(KGDSO(1).EQ.0) CALL POLFIXS(NO,MO,KM,RLAT,RLON,IBO,LO,GO)
C - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      END
