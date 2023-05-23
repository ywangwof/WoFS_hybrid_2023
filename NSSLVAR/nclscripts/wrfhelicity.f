c-----------------------------------------------------------------------
C NCLFORTSTART
      SUBROUTINE wrf_helicity_custom(HELI,U3D,V3D,P,T,Z,NX,NY,NZ,LEVEL)
        IMPLICIT NONE
        INTEGER  NX,NY,NZ
        REAL     HELI(NX,NY), LEVEL
        REAL     U3D(NX,NY,NZ),V3D(NX,NY,NZ),Z(NX,NY,NZ)
        REAL     P(NX,NY,NZ),T(NX,NY,NZ)
C NCLEND
        integer :: i, j, k, k3km
!       real    :: u3d(nx,ny,nz), v3d(nx,ny,nz)
        real    :: sumu, sumv, sump, sumh, ushr, vshr
        real    :: u6km, v6km, p6km, t6km, u3km, v3km
        real    :: dp, dz, rhohi, rholo, rhoinv, whigh, wlow
        real    :: dirmean, spmean, ddir, perc
        real    :: ustrm(nx,ny), vstrm(nx,ny)
        real    :: tem1(nx,ny)

!
!-----------------------------------------------------------------------
!
!  Input Check
!
!-----------------------------------------------------------------------
!
      IF ( (level .ne. 3000) .and. (LEVEL .ne. 1000) ) THEN
         level=3000.
      WRITE(*,*) 'Warning: Only 3km or 1km is accepted for calculating  &
     &helicity.'
      WRITE(*,*) 'Calculating helicity between surface and ',level, 'm.'
      ELSE
      WRITE(*,*) 'Calculating helicity between surface and ',level, 'm.'
      END IF
!
!-----------------------------------------------------------------------
!
!  Find mass weighted mean wind sfc-6km AGL
!
!-----------------------------------------------------------------------
!
      DO j=1,ny
         DO i=1,nx
            sumu=0.
            sumv=0.
            sump=0.
            DO k=2,nz
               IF (z(i,j,k)<=6000) THEN
                  dp=p(i,j,k-1)-p(i,j,k)
                  rhohi=p(i,j,k)/t(i,j,k)
                  rholo=p(i,j,k-1)/t(i,j,k-1)
                  rhoinv=1./(rhohi+rholo)
                  sumu=sumu+dp*rhoinv*(rholo*u3d(i,j,k-1)+              &
     &                                 rhohi*u3d(i,j,k))
                  sumv=sumv+dp*rhoinv*(rholo*v3d(i,j,k-1)+              &
     &                                 rhohi*v3d(i,j,k))
                  sump=sump+dp
               ELSE
                  dz=z(i,j,k)-z(i,j,k-1)
                  wlow=(z(i,j,k)-6000)/dz
                  u6km=u3d(i,j,k)*(1.-wlow) + u3d(i,j,k-1)*wlow
                  v6km=v3d(i,j,k)*(1.-wlow) + v3d(i,j,k-1)*wlow
                  p6km=p(i,j,k)*(1.-wlow)   + p(i,j,k-1)*wlow
                  t6km=t(i,j,k)*(1.-wlow)   + t(i,j,k-1)*wlow
                  dp=p(i,j,k-1)-p6km
                  rhohi=p6km/t6km
                  rholo=p(i,j,k-1)/t(i,j,k-1)
                  rhoinv=1./(rhohi+rholo)
                  sumu=sumu+dp*rhoinv*(rholo*u3d(i,j,k-1)+rhohi*u6km)
                  sumv=sumv+dp*rhoinv*(rholo*v3d(i,j,k-1)+rhohi*v6km)
                  sump=sump+dp
                  EXIT
               END IF
            END DO
            u6km=sumu/sump
            v6km=sumv/sump
!
!-----------------------------------------------------------------------
!
!  Storm motion estimation
!  From Davies and Johns, 1993
!  "Some wind and instability parameters associated With
!  strong and violent tornadoes."
!  AGU Monograph 79, The Tornado...(Page 575)
!
!  Becuase of the discontinuity produced by that method
!  at the 15.5 m/s cutoff, their rules have been modified
!  to provide a gradual transition, and accomodate all the
!  data they mention in the article.
!
!-----------------------------------------------------------------------
!
            CALL uv2ddff(u6km,v6km,dirmean,spmean)
            IF(spmean >= 20.0) THEN
               dirmean=dirmean+18.
               IF(dirmean > 360.) dirmean=dirmean-360.
               spmean=spmean*0.89
            ELSE IF (spmean > 8.0) THEN
               whigh=(spmean - 8.0)/12.
               wlow =1.-whigh
               ddir=wlow*32.0 + whigh*18.0
               perc=wlow*0.75 + whigh*0.89
               dirmean=dirmean+ddir
               IF(dirmean > 360.) dirmean=dirmean-360.
               spmean=spmean*perc
            ELSE
               dirmean=dirmean+32.
               IF(dirmean > 360.) dirmean=dirmean-360.
               spmean=spmean*0.75
            END IF
            CALL ddff2uv(dirmean,spmean,ustrm(i,j),vstrm(i,j))
         END DO
      END DO
!
!-----------------------------------------------------------------------
!
!  Calculate Helicity
!
!  For more efficient computation the Helicity is
!  computed for zero storm motion and the storm
!  motion is accounted for by adding a term at the end.
!  This is mathematically equivalent to accounting
!  for the storm motion at each level.
!
!-----------------------------------------------------------------------
!
      DO j=1,ny
         DO i=1,nx
            sumh=0.
            DO k=2,nz
               IF (z(i,j,k) > level) EXIT
               sumh=sumh + ( u3d(i,j,k)*v3d(i,j,k-1) ) -                &
     &                     ( v3d(i,j,k)*u3d(i,j,k-1) )
            END DO
            k3km=k
            dz=z(i,j,k)-z(i,j,k-1)
            wlow=(z(i,j,k)-level)/dz
            u3km=u3d(i,j,k)*(1.-wlow) + u3d(i,j,k-1)*wlow
            v3km=v3d(i,j,k)*(1.-wlow) + v3d(i,j,k-1)*wlow
            sumh=sumh + ( u3km*v3d(i,j,k-1) ) -                         &
     &                  ( v3km*u3d(i,j,k-1) )
            ushr=u3km-u3d(i,j,1)
            vshr=v3km-v3d(i,j,1)
            heli(i,j)=sumh + vshr*ustrm(i,j) - ushr*vstrm(i,j)
         END DO
      END DO

      CALL smooth9p(heli,nx,ny,1,nx,1,ny,0,tem1)
     
      END SUBROUTINE wrf_helicity_custom


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!  Necessary subroutines below
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!
!##################################################################
!##################################################################
!######                                                      ######
!######                SUBROUTINE UV2DDFF                    ######
!######                                                      ######
!######                     Developed by                     ######
!######     Center for Analysis and Prediction of Storms     ######
!######                University of Oklahoma                ######
!######                                                      ######
!##################################################################
!##################################################################
!

      SUBROUTINE uv2ddff(u,v,dd,ff)
!
!-----------------------------------------------------------------------
!
!  PURPOSE:
!
!  Calculate direction and speed from u and v.
!
!-----------------------------------------------------------------------
!
!
!  AUTHOR: Keith Brewster
!  3/11/1996
!
!-----------------------------------------------------------------------
!
        IMPLICIT NONE
        REAL :: u,v,dd,ff
        REAL :: dlon
        REAL :: r2deg
        PARAMETER (r2deg=180./3.141592654)
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
!  Beginning of executable code...
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
!
        ff = SQRT(u*u + v*v)
      
        IF(v > 0.) THEN
          dlon=r2deg*ATAN(u/v)
        ELSE IF(v < 0.) THEN
          dlon=180. + r2deg*ATAN(u/v)
        ELSE IF(u >= 0.) THEN
          dlon=90.
        ELSE
          dlon=-90.
        END IF
      
        dd= dlon + 180.
        dd= dd-360.*(nint(dd)/360)
        RETURN
      END SUBROUTINE uv2ddff

!
!##################################################################
!##################################################################
!######                                                      ######
!######                SUBROUTINE DDFF2UV                    ######
!######                                                      ######
!######                     Developed by                     ######
!######     Center for Analysis and Prediction of Storms     ######
!######                University of Oklahoma                ######
!######                                                      ######
!##################################################################
!##################################################################
!

      SUBROUTINE ddff2uv(dd,ff,u,v)
!
!-----------------------------------------------------------------------
!
!  PURPOSE:
!
!  Calculate u and v wind components from direction and speed.
!
!-----------------------------------------------------------------------
!
!
!  AUTHOR: Keith Brewster
!  3/11/1996
!
!-----------------------------------------------------------------------
!
        IMPLICIT NONE
        REAL :: u,v,dd,ff
        REAL :: arg
        REAL :: d2rad
        PARAMETER (d2rad=3.141592654/180.)
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
!  Beginning of executable code...
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
        arg = (dd * d2rad)
        u = -ff * SIN(arg)
        v = -ff * COS(arg)
        RETURN
      END SUBROUTINE ddff2uv
!
!##################################################################
!##################################################################
!######                                                      ######
!######                SUBROUTINE SMOOTH9P                   ######
!######                                                      ######
!######                     Developed by                     ######
!######     Center for Analysis and Prediction of Storms     ######
!######                University of Oklahoma                ######
!######                                                      ######
!##################################################################
!##################################################################
!
!

      SUBROUTINE smooth9p(arr,nx,ny,ibgn,iend,jbgn,jend,                &
     &                    stagdim,tem1)
!
!-----------------------------------------------------------------------
!
!  PURPOSE:
!
!                                        1 2 1
!  Smooth a 2-D array by the filter of { 2 4 2 }
!                                        1 2 1
!
!-----------------------------------------------------------------------
!
!  AUTHOR:       Yuhe Liu
!
!  5/3/94
!
!  Modification History
!  8/20/1995 (M. Xue)
!  Fixed errors in the index bound of loops 100 and 200.
!
!-----------------------------------------------------------------------
!
!  INPUT:
!
!  nx       Number of grid points in the x-direction
!  ny       Number of grid points in the y-direction
!  ibgn     First index in x-direction in the soomthing region.
!  iend     Last  index in x-direction in the soomthing region.
!  jbgn     First index in j-direction in the soomthing region.
!  jend     Last  index in j-direction in the soomthing region.
!
!  arr    2-D array
!
!  OUTPUT:
!
!  arr    2-D array
!
!  TEMPORARY:
!
!  tem1     Temporary 2-D array
!
!-----------------------------------------------------------------------
!
!  Variable Declarations.
!
!-----------------------------------------------------------------------
!
        IMPLICIT NONE

        INTEGER :: nx         ! Number of grid points in the x-direction
        INTEGER :: ny         ! Number of grid points in the y-direction
        INTEGER :: ibgn
        INTEGER :: iend
        INTEGER :: jbgn
        INTEGER :: jend
        INTEGER, INTENT(IN) :: stagdim
      
        REAL :: arr (nx,ny)   ! 2-D array

        REAL :: tem1(nx,ny)   ! Temporary array
!
!-----------------------------------------------------------------------
!
!  Misc. local variables:
!
!-----------------------------------------------------------------------
!
        INTEGER :: i,j
        REAL :: wtf,wtfb,wtfc
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
!  Beginning of executable code...
!
!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!
        wtf  = 1.0/16.0
        wtfb = 1.0/12.0
        wtfc = 1.0/9.0
      
        DO j = jbgn+1, jend-1
          DO i = ibgn+1, iend-1
      
            tem1(i,j) = wtf                                             &
     &          * (    arr(i-1,j-1) + 2.*arr(i,j-1) +    arr(i+1,j-1)   &
     &            + 2.*arr(i-1,j  ) + 4.*arr(i,j  ) + 2.*arr(i+1,j  )   &
     &            +    arr(i-1,j+1) + 2.*arr(i,j+1) +    arr(i+1,j+1) )
      
          END DO
        END DO
      
        DO j = jbgn+1, jend-1
          tem1(ibgn,j) = wtfb                                           &
     &        * ( 2.*arr(ibgn,j-1) +    arr(ibgn+1,j-1)                 &
     &        + 4.*arr(ibgn,j  ) + 2.*arr(ibgn+1,j  )                   &
     &        + 2.*arr(ibgn,j+1) +    arr(ibgn+1,j+1) )
          tem1(iend,j) = wtfb                                           &
     &        * (    arr(iend-1,j-1)  + 2.*arr(iend,j-1)                &
     &        + 2.*arr(iend-1,j  )  + 4.*arr(iend,j  )                  &
     &        +    arr(iend-1,j+1)  + 2.*arr(iend,j+1) )
      
        END DO
      
        DO i = ibgn+1, iend-1
          tem1(i,jbgn) = wtfb                                           &
     &        * ( 2.*arr(i-1,jbgn) + 4.*arr(i,jbgn) + 2.*arr(i+1,jbgn)  &
     &        +   arr(i-1,jbgn+1) + 2.*arr(i,jbgn+1) + arr(i+1,jbgn+1) )
      
          tem1(i,jend) = wtfb                                           &
     &        * ( arr(i-1,jend-1) + 2.*arr(i,jend-1) + arr(i+1,jend-1)  &
     &        +  2.*arr(i-1,jend) + 4.*arr(i,jend) + 2.*arr(i+1,jend) )
      
        END DO
      
        tem1(ibgn,jbgn) = wtfc                                          &
     &      * ( 2.*arr(ibgn,jbgn+1) +    arr(ibgn+1,jbgn+1)             &
     &      + 4.*arr(ibgn,jbgn  ) + 2.*arr(ibgn+1,jbgn  ) )
      
        tem1(ibgn,jend) = wtfc                                          &
     &      * ( 4.*arr(ibgn,jend  ) + 2.*arr(ibgn+1,jend  )             &
     &      + 2.*arr(ibgn,jend-1) +    arr(ibgn+1,jend-1) )
      
        tem1(iend,jbgn) = wtfc                                          &
     &      * (    arr(iend-1,jbgn+1) + 2.*arr(iend,jbgn+1)             &
     &      + 2.*arr(iend-1,jbgn  ) + 4.*arr(iend,jbgn  ) )
      
        tem1(iend,jend) = wtfc                                          &
     &      * ( 2.*arr(iend-1,jend  ) + 4.*arr(iend,  jend)             &
     &       +    arr(iend-1,jend-1) + 2.*arr(iend-1,jend) )
      
        DO j = 1, ny
          DO i = 1, nx
            arr(i,j) = tem1(i,j)
          END DO
        END DO
      
        RETURN
      END SUBROUTINE smooth9p
      
