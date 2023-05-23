c--------------------------------------------------------
C NCLFORTSTART
      SUBROUTINE DCOMPUTECURL(CRL,U,V,MSFT,DX,DY,NX,NY,NZ)
        IMPLICIT NONE
        INTEGER NX,NY,NZ
        DOUBLE PRECISION U(NX,NY,NZ),V(NX,NY,NZ)
        DOUBLE PRECISION CRL(NX,NY,NZ),MSFT(NX,NY)
        DOUBLE PRECISION DX,DY
C NCLEND
        INTEGER JP1,JM1,IP1,IM1,I,J,K
        DOUBLE PRECISION DSY,DSX,DVDX,DUDY
        DOUBLE PRECISION MM
        DOUBLE PRECISION w_m
        INTEGER n
        DOUBLE PRECISION temx(NX), temy(NY)
c Note all data must be on T-pts
        DO K = 1,NZ
          DO J = 1,NY
            JP1 = MIN(J+1,NY)
            JM1 = MAX(J-1,1)
            DO I = 1,NX
c--------------------added and tested by Gao----------
              IP1 = MIN(I+1,NX)
              IM1 = MAX(I-1,1)

              DSX = (IP1-IM1)*DX
              DSY = (JP1-JM1)*DY
c Careful with map factors...
              MM = MSFT(I,J)*MSFT(I,J)
              DVDX = (V(IP1,J,K)/MSFT(IP1,J) -
     +                V(IM1,J,K)/MSFT(IM1,J))/DSX*MM
              DUDY = (U(I,JP1,K)/MSFT(I,JP1) -
     +                U(I,JM1,K)/MSFT(I,JM1))/DSY*MM

              CRL(I,J,K) = DVDX - DUDY
            END DO
          END DO
        END DO

c       Smoothing

        w_m = 20.0

c        DO n=1, 1
        n = 2

          DO K = 1,NZ
            DO J = 1,NY

              DO I = 1,NX
                temx(I) = CRL(I,J,K)
              END DO

              CALL recurfilt1d(NX,temx,n,w_m)

              DO I = 1,NX
                CRL(I,J,K) = temx(I)
              END DO

            END DO
          END DO

          DO K = 1,NZ
            DO I = 1,NX

              DO J = 1,NY
                temy(J) = CRL(I,J,K)
              END DO

              CALL recurfilt1d(NY,temy,n,w_m)

              DO J = 1,NY
                CRL(I,J,K) = temy(J)
              END DO

            END DO
          END DO

c        END DO

        RETURN
      END


      SUBROUTINE recurfilt1d(nz,pgrd,ipass_filt,radius)

        IMPLICIT NONE

        INTEGER           nz,ipass_filt
        DOUBLE PRECISION  radius


        DOUBLE PRECISION  pgrd(nz)

C-----------------------------------------------------------------------
C
C Misc local variables
C
C-----------------------------------------------------------------------

        DOUBLE PRECISION alpha(nz)
        DOUBLE PRECISION  beta(nz)
        DOUBLE PRECISION    ee(nz)
        DOUBLE PRECISION temp1,temp2
        INTEGER          i,j,k,n

C
C@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
C
        IF( int(radius) == 0 ) return

        DO k=1, nz
          ee(k) = REAL(ipass_filt) / REAL (radius*radius)
          alpha(k) = 1 + ee(k) - SQRT (ee(k)*(ee(k)+2.))
          beta(k)  = 1. - alpha(k)
        END DO

        DO n = 1, ipass_filt/2
C-----------------------------------------------------------------------
C
C Z direction - forward
C
C-----------------------------------------------------------------------

          SELECT CASE (n)
          CASE (1)
             pgrd(1) = beta(1) * pgrd(1)
          CASE (2)
            temp1 = 1.-alpha(1)*alpha(1)
            pgrd(1) = beta(1)/temp1 * pgrd(1)
          CASE (3)
            temp1 = (1-alpha(1))/
     +              ((1-alpha(1)*alpha(1))*(1-alpha(1)*alpha(1)))
            temp2 =alpha(1)*alpha(1)*alpha(1)
            pgrd(1) = temp1 * (pgrd(1)-temp2*pgrd(1))
          CASE DEFAULT
            temp2 =alpha(1)*alpha(1)*alpha(1)
            temp1 = (1-alpha(1))/(1-3*alpha(1)*alpha(1)+
     +                             3*temp2*alpha(1)-temp2*temp2)
            pgrd(1) = temp1 * (pgrd(1)-3*temp2*pgrd(2)+
     +                         temp2*alpha(1)*alpha(1)*pgrd(2)+
     +                         temp2*alpha(1)*pgrd(3))
          END SELECT

          DO k = 2, nz, 1
            pgrd(k) = alpha(k)*pgrd(k-1) + beta(k)*pgrd(k)
          END DO

C-----------------------------------------------------------------------
C
C Z direction - backward
C
C-----------------------------------------------------------------------

          SELECT CASE (n)
          CASE (0)
            pgrd(nz) = beta(nz) * pgrd(nz)
          CASE (1)
            temp1 = (1.-alpha(nz)*alpha(nz))
            pgrd(nz) = beta(nz)/temp1 * pgrd(nz)
          CASE (2)
            temp1 = (1-alpha(nz))/((1-alpha(nz)*alpha(nz))*
     +                             (1-alpha(nz)*alpha(nz)))
            temp2 = alpha(nz)*alpha(nz)*alpha(nz)
            pgrd(nz) = temp1 * (pgrd(nz)-temp2*pgrd(nz-1))
          CASE DEFAULT
            temp2 = alpha(nz)*alpha(nz)*alpha(nz)
            temp1 = (1-alpha(nz))/(1-3*alpha(nz)*alpha(nz)+
     +                               3*temp2*alpha(nz)-temp2*temp2)
            pgrd(nz) = temp1 * (pgrd(nz)-3*temp2*pgrd(nz-1)+
     +                          temp2*alpha(nz)*alpha(nz)*pgrd(nz-1)+
     +                          temp2*alpha(nz)*pgrd(nz-2))
          END SELECT

          DO k = nz-1, 1, -1
            pgrd(k) = alpha(k)*pgrd(k+1) + beta(k)*pgrd(k)
          END DO

        END DO

        RETURN
      END SUBROUTINE recurfilt1d
