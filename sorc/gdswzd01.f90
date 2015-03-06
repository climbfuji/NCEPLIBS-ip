 SUBROUTINE GDSWZD01(IGDTNUM,IGDTMPL,IGDTLEN,IOPT,NPTS,FILL, &
                     XPTS,YPTS,RLON,RLAT,NRET, &
                     LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!
! SUBPROGRAM:  GDSWZD01   GDS WIZARD FOR MERCATOR CYLINDRICAL
!   PRGMMR: IREDELL       ORG: W/NMC23       DATE: 96-04-10
!
! ABSTRACT: THIS SUBPROGRAM DECODES THE GRIB GRID DESCRIPTION SECTION
!           (PASSED IN INTEGER FORM AS DECODED BY SUBPROGRAM W3FI63)
!           AND RETURNS ONE OF THE FOLLOWING:
!             (IOPT=+1) EARTH COORDINATES OF SELECTED GRID COORDINATES
!             (IOPT=-1) GRID COORDINATES OF SELECTED EARTH COORDINATES
!           FOR MERCATOR CYLINDRICAL PROJECTIONS.
!           IF THE SELECTED COORDINATES ARE MORE THAN ONE GRIDPOINT
!           BEYOND THE THE EDGES OF THE GRID DOMAIN, THEN THE RELEVANT
!           OUTPUT ELEMENTS ARE SET TO FILL VALUES.
!           THE ACTUAL NUMBER OF VALID POINTS COMPUTED IS RETURNED TOO.
!           OPTIONALLY, THE VECTOR ROTATIONS AND THE MAP JACOBIANS
!           FOR THIS GRID MAY BE RETURNED AS WELL.
!
! PROGRAM HISTORY LOG:
!   96-04-10  IREDELL
!   96-10-01  IREDELL   PROTECTED AGAINST UNRESOLVABLE POINTS
!   97-10-20  IREDELL  INCLUDE MAP OPTIONS
!
! USAGE:    CALL GDSWZD01(KGDS,IOPT,NPTS,FILL,XPTS,YPTS,RLON,RLAT,NRET,
!    &                    LROT,CROT,SROT,LMAP,XLON,XLAT,YLON,YLAT,AREA)
!
!   INPUT ARGUMENT LIST:
!     KGDS     - INTEGER (200) GDS PARAMETERS AS DECODED BY W3FI63
!     IOPT     - INTEGER OPTION FLAG
!                (+1 TO COMPUTE EARTH COORDS OF SELECTED GRID COORDS)
!                (-1 TO COMPUTE GRID COORDS OF SELECTED EARTH COORDS)
!     NPTS     - INTEGER MAXIMUM NUMBER OF COORDINATES
!     FILL     - REAL FILL VALUE TO SET INVALID OUTPUT DATA
!                (MUST BE IMPOSSIBLE VALUE; SUGGESTED VALUE: -9999.)
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT>0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT>0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT<0
!                (ACCEPTABLE RANGE: -360. TO 360.)
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT<0
!                (ACCEPTABLE RANGE: -90. TO 90.)
!     LROT     - INTEGER FLAG TO RETURN VECTOR ROTATIONS IF 1
!     LMAP     - INTEGER FLAG TO RETURN MAP JACOBIANS IF 1
!
!   OUTPUT ARGUMENT LIST:
!     XPTS     - REAL (NPTS) GRID X POINT COORDINATES IF IOPT<0
!     YPTS     - REAL (NPTS) GRID Y POINT COORDINATES IF IOPT<0
!     RLON     - REAL (NPTS) EARTH LONGITUDES IN DEGREES E IF IOPT>0
!     RLAT     - REAL (NPTS) EARTH LATITUDES IN DEGREES N IF IOPT>0
!     NRET     - INTEGER NUMBER OF VALID POINTS COMPUTED
!     CROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION COSINES IF LROT=1
!     SROT     - REAL (NPTS) CLOCKWISE VECTOR ROTATION SINES IF LROT=1
!                (UGRID=CROT*UEARTH-SROT*VEARTH;
!                 VGRID=SROT*UEARTH+CROT*VEARTH)
!     XLON     - REAL (NPTS) DX/DLON IN 1/DEGREES IF LMAP=1
!     XLAT     - REAL (NPTS) DX/DLAT IN 1/DEGREES IF LMAP=1
!     YLON     - REAL (NPTS) DY/DLON IN 1/DEGREES IF LMAP=1
!     YLAT     - REAL (NPTS) DY/DLAT IN 1/DEGREES IF LMAP=1
!     AREA     - REAL (NPTS) AREA WEIGHTS IN M**2 IF LMAP=1
!                (PROPORTIONAL TO THE SQUARE OF THE MAP FACTOR)
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90
!
!$$$
 IMPLICIT NONE
!
 INTEGER,           INTENT(IN   ) :: IGDTNUM, IGDTLEN
 INTEGER(KIND=4),   INTENT(IN   ) :: IGDTMPL(IGDTLEN)
 INTEGER,           INTENT(IN   ) :: IOPT
 INTEGER,           INTENT(IN   ) :: LMAP, LROT, NPTS
 INTEGER,           INTENT(  OUT) :: NRET
!
 REAL,              INTENT(IN   ) :: FILL
 REAL,              INTENT(INOUT) :: RLON(NPTS),RLAT(NPTS)
 REAL,              INTENT(INOUT) :: XPTS(NPTS),YPTS(NPTS)
 REAL,              INTENT(  OUT) :: CROT(NPTS),SROT(NPTS)
 REAL,              INTENT(  OUT) :: XLON(NPTS),XLAT(NPTS)
 REAL,              INTENT(  OUT) :: YLON(NPTS),YLAT(NPTS),AREA(NPTS)
!
 REAL,              PARAMETER     :: RERTH=6.3712E6
 REAL,              PARAMETER     :: PI=3.14159265358979
 REAL,              PARAMETER     :: DPR=180./PI
!
 INTEGER                          :: ISCAN, JSCAN
 INTEGER                          :: IM, JM, N
!
 REAL                             :: DLON, DPHI, DY
 REAL                             :: HI, HJ
 REAL                             :: RLAT1, RLON1, RLON2, RLATI
 REAL                             :: XMAX, XMIN, YMAX, YMIN
 REAL                             :: YE
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 IF(IGDTNUM==10) THEN
   IM=IGDTMPL(8)
   JM=IGDTMPL(9)
   RLAT1=FLOAT(IGDTMPL(10))*1.0E-6
   RLON1=FLOAT(IGDTMPL(11))*1.0E-6
   RLON2=FLOAT(IGDTMPL(15))*1.0E-6
   RLATI=FLOAT(IGDTMPL(13))*1.0E-6
   ISCAN=MOD(IGDTMPL(16)/128,2)
   JSCAN=MOD(IGDTMPL(16)/64,2)
   DY=FLOAT(IGDTMPL(19))*1.0E-3
   HI=(-1.)**ISCAN
   HJ=(-1.)**(1-JSCAN)
   DLON=HI*(MOD(HI*(RLON2-RLON1)-1+3600,360.)+1)/(IM-1)
   DPHI=HJ*DY/(RERTH*COS(RLATI/DPR))
   YE=1-LOG(TAN((RLAT1+90)/2/DPR))/DPHI
   XMIN=0
   XMAX=IM+1
   IF(IM.EQ.NINT(360/ABS(DLON))) XMAX=IM+2
   YMIN=0
   YMAX=JM+1
   NRET=0
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE GRID COORDINATES TO EARTH COORDINATES
   IF(IOPT.EQ.0.OR.IOPT.EQ.1) THEN
     DO N=1,NPTS
       IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
          YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
         RLON(N)=MOD(RLON1+DLON*(XPTS(N)-1)+3600,360.)
         RLAT(N)=2*ATAN(EXP(DPHI*(YPTS(N)-YE)))*DPR-90
         NRET=NRET+1
         IF(LROT.EQ.1) THEN
           CROT(N)=1
           SROT(N)=0
         ENDIF
         IF(LMAP.EQ.1) THEN
           XLON(N)=1/DLON
           XLAT(N)=0.
           YLON(N)=0.
           YLAT(N)=1/DPHI/COS(RLAT(N)/DPR)/DPR
           AREA(N)=RERTH**2*COS(RLAT(N)/DPR)**2*DPHI*DLON/DPR
         ENDIF
       ELSE
         RLON(N)=FILL
         RLAT(N)=FILL
       ENDIF
     ENDDO
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  TRANSLATE EARTH COORDINATES TO GRID COORDINATES
   ELSEIF(IOPT.EQ.-1) THEN
     DO N=1,NPTS
       IF(ABS(RLON(N)).LE.360.AND.ABS(RLAT(N)).LT.90) THEN
         XPTS(N)=1+HI*MOD(HI*(RLON(N)-RLON1)+3600,360.)/DLON
         YPTS(N)=YE+LOG(TAN((RLAT(N)+90)/2/DPR))/DPHI
         IF(XPTS(N).GE.XMIN.AND.XPTS(N).LE.XMAX.AND. &
            YPTS(N).GE.YMIN.AND.YPTS(N).LE.YMAX) THEN
           NRET=NRET+1
           IF(LROT.EQ.1) THEN
             CROT(N)=1
             SROT(N)=0
           ENDIF
           IF(LMAP.EQ.1) THEN
             XLON(N)=1/DLON
             XLAT(N)=0.
             YLON(N)=0.
             YLAT(N)=1/DPHI/COS(RLAT(N)/DPR)/DPR
             AREA(N)=RERTH**2*COS(RLAT(N)/DPR)**2*DPHI*DLON/DPR
           ENDIF
         ELSE
           XPTS(N)=FILL
           YPTS(N)=FILL
         ENDIF
       ELSE
         XPTS(N)=FILL
         YPTS(N)=FILL
       ENDIF
     ENDDO
   ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
!  PROJECTION UNRECOGNIZED
 ELSE
   IF(IOPT.GE.0) THEN
     DO N=1,NPTS
       RLON(N)=FILL
       RLAT(N)=FILL
     ENDDO
   ENDIF
   IF(IOPT.LE.0) THEN
     DO N=1,NPTS
       XPTS(N)=FILL
       YPTS(N)=FILL
     ENDDO
   ENDIF
 ENDIF
! - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 END SUBROUTINE GDSWZD01
