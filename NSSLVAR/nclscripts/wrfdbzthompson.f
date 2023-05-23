c--------------------------------------------------------
C NCLFORTSTART
      SUBROUTINE wrf_dbz_thompson(DBZ, P,TK,QV, QC,QR,NR,QS,QG,NX,NY,NZ)
        IMPLICIT NONE
        INTEGER  NX,NY,NZ
        REAL     P(NX,NY,NZ),TK(NX,NY,NZ),QV(NX,NY,NZ)
        REAL     QC(NX,NY,NZ),QR(NX,NY,NZ),NR(NX,NY,NZ)
        REAL     QS(NX,NY,NZ),QG(NX,NY,NZ)
        REAL     DBZ(NX,NY,NZ)
C NCLEND
        INTEGER :: i,j,k,its,ite,jts,jte,kts,kte,ide,jde
        INTEGER :: istatus

        REAL, ALLOCATABLE :: t1d(:),p1d(:),qv1d(:)
        REAL, ALLOCATABLE :: qc1d(:),qr1d(:),nr1d(:)
        REAL, ALLOCATABLE :: qs1d(:),qg1d(:),dbz1d(:)

!@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

c ----- Note all data must be on T-pts -----------------
        its = 1; ite = nx; ide = nx
        jts = 1; jte = ny; jde = nx
        kts = 1; kte = nz

        ALLOCATE( t1d (kts:kte),  STAT = istatus )
        ALLOCATE( p1d (kts:kte),  STAT = istatus )
        ALLOCATE( qv1d(kts:kte),  STAT = istatus )
        ALLOCATE( qc1d(kts:kte),  STAT = istatus )
        ALLOCATE( qr1d(kts:kte),  STAT = istatus )
        ALLOCATE( qs1d(kts:kte),  STAT = istatus )
        ALLOCATE( qg1d(kts:kte),  STAT = istatus )
        ALLOCATE( nr1d(kts:kte),  STAT = istatus )
        ALLOCATE( dbz1d(kts:kte), STAT = istatus )

        DO j = jts, MIN(jte, jde-1)
          DO i = its, MIN(ite, ide-1)

              do k = kts, kte
                 t1d(k)  = tk(i,j,k)
                 p1d(k)  = p (i,j,k)
                 qv1d(k) = qv(i,j,k)
                 qc1d(k) = qc(i,j,k)
                 qr1d(k) = qr(i,j,k)
                 qs1d(k) = qs(i,j,k)
                 qg1d(k) = qg(i,j,k)
                 nr1d(k) = nr(i,j,k)
              enddo

              call calc_refl10cm (qv1d, qc1d, qr1d, nr1d, qs1d, qg1d,   &
     &                            t1d, p1d, dBZ1d, kts, kte, i, j)

              do k = kts, kte
                 dbz(i,j,k) = MAX(-35., dBZ1d(k))
              enddo

          END DO
        END DO

        DEALLOCATE( t1d ,  STAT = istatus )
        DEALLOCATE( p1d ,  STAT = istatus )
        DEALLOCATE( qv1d,  STAT = istatus )
        DEALLOCATE( qc1d,  STAT = istatus )
        DEALLOCATE( qr1d,  STAT = istatus )
        DEALLOCATE( qs1d,  STAT = istatus )
        DEALLOCATE( qg1d,  STAT = istatus )
        DEALLOCATE( nr1d,  STAT = istatus )
        DEALLOCATE( dbz1d, STAT = istatus )

      END SUBROUTINE wrf_dbz_thompson

!#######################################################################

      subroutine calc_refl10cm (qv1d, qc1d, qr1d, nr1d, qs1d, qg1d,     &
     &                          t1d, p1d, dBZ, kts, kte, ii, jj)

      IMPLICIT NONE

!..Sub arguments
      INTEGER, INTENT(IN):: kts, kte, ii, jj
      REAL, DIMENSION(kts:kte), INTENT(IN)::                            &
     &                    qv1d, qc1d, qr1d, nr1d, qs1d, qg1d, t1d, p1d
      REAL, DIMENSION(kts:kte), INTENT(INOUT):: dBZ
!     REAL, DIMENSION(kts:kte), INTENT(INOUT):: vt_dBZ

!..Local variables
      REAL, DIMENSION(kts:kte):: temp, pres, qv, rho, rhof
      REAL, DIMENSION(kts:kte):: rc, rr, nr, rs, rg

      DOUBLE PRECISION, DIMENSION(kts:kte):: ilamr, ilamg, N0_r, N0_g
      REAL, DIMENSION(kts:kte):: mvd_r
      REAL, DIMENSION(kts:kte):: smob, smo2, smoc, smoz
      REAL:: oM3, M0, Mrat, slam1, slam2, xDs
      REAL:: ils1, ils2, t1_vts, t2_vts, t3_vts, t4_vts
      REAL:: vtr_dbz_wt, vts_dbz_wt, vtg_dbz_wt

      REAL, DIMENSION(kts:kte):: ze_rain, ze_snow, ze_graupel

      DOUBLE PRECISION:: N0_exp, N0_min, lam_exp, lamr, lamg
      REAL:: a_, b_, loga_, tc0
      DOUBLE PRECISION:: fmelt_s, fmelt_g

      INTEGER:: i, k, k_0, kbot, n
      LOGICAL:: melti
      LOGICAL, DIMENSION(kts:kte):: L_qr, L_qs, L_qg

      DOUBLE PRECISION:: cback, x, eta, f_d
      REAL:: xslw1, ygra1, zans1

      REAL, PARAMETER :: PI = 3.1415926536
      REAL, PARAMETER :: R = 287.04
      REAL, PARAMETER :: R1 = 1.E-12
      REAL, PARAMETER :: R2 = 1.E-6

      REAL, PARAMETER :: rho_not = 101325.0/(287.05*298.0)

      REAL, PARAMETER :: gonv_min = 1.E4
      REAL, PARAMETER :: gonv_max = 3.E6

      REAL, PARAMETER :: rho_w = 1000.0
      REAL, PARAMETER :: rho_g = 500.0

      REAL, PARAMETER :: am_s = 0.069
      REAL, PARAMETER :: bm_s = 2.0
      REAL, PARAMETER :: am_g = PI*rho_g/6.0
      REAL, PARAMETER :: bm_g = 3.0
      REAL, PARAMETER :: am_r = PI*rho_w/6.0
      REAL, PARAMETER :: bm_r = 3.0

      REAL, PARAMETER :: bv_g = 0.89

      REAL, PARAMETER :: mu_g = 0.0
      REAL, PARAMETER :: mu_r = 0.0
      REAL, PARAMETER :: mu_s = 0.6357

      LOGICAL, PARAMETER :: iiwarm = .false.
      REAL,    PARAMETER :: Kap0 = 490.6
      REAL,    PARAMETER :: Kap1 = 17.46
      REAL,    PARAMETER :: Lam0 = 20.78
      REAL,    PARAMETER :: Lam1 = 3.29

      REAL :: oams, obms, ocms, obmr
      REAL, DIMENSION(12) :: cge, cgg
      REAL :: oge1, ogg1, ogg2, ogg3, oamg, obmg, ocmg

      REAL, DIMENSION(13) :: cre, crg
      REAL :: ore1, org1, org2, org3

      REAL, DIMENSION(10), PARAMETER ::                                 &
     & sa = (/ 5.065339, -0.062659, -3.032362, 0.029469, -0.000285,     &
     &         0.31255,   0.000204,  0.003199, 0.0,      -0.015952/)
      REAL, DIMENSION(10), PARAMETER ::                                 &
     & sb = (/ 0.476221, -0.015896,  0.165977, 0.007468, -0.000141,     &
     &         0.060366,  0.000079,  0.000594, 0.0,      -0.003577/)

      REAL, DIMENSION(18) :: cse

C------ Added from module_mp_radar.F -----------------------------------

      INTEGER, PARAMETER :: nrbins = 50
      DOUBLE PRECISION, DIMENSION(nrbins+1) :: xxDx
      DOUBLE PRECISION, DIMENSION(nrbins)   :: xxDs,xdts,xxDg,xdtg
      DOUBLE PRECISION, DIMENSION(nrbins+1) :: simpson

      DOUBLE PRECISION, DIMENSION(3), PARAMETER :: basis =              &
     &                      (/1.d0/3.d0, 4.d0/3.d0, 1.d0/3.d0/)

      INTEGER, PARAMETER :: slen = 20
      CHARACTER(len=slen) ::                                            &
     &         mixingrulestring_s, matrixstring_s, inclusionstring_s,   &
     &         hoststring_s, hostmatrixstring_s, hostinclusionstring_s, &
     &         mixingrulestring_g, matrixstring_g, inclusionstring_g,   &
     &         hoststring_g, hostmatrixstring_g, hostinclusionstring_g

      DOUBLE PRECISION, PARAMETER :: lamda_radar = 0.10
      COMPLEX*16       :: m_w_0, m_i_0
      DOUBLE PRECISION :: K_w, PI5, lamda4

      DOUBLE PRECISION, PARAMETER :: melt_outside_s = 0.9d0
      DOUBLE PRECISION, PARAMETER :: melt_outside_g = 0.9d0

      COMPLEX*16 :: m_complex_water_ray, m_complex_ice_maetzler
      REAL       :: WGAMMA

!+---+

      do n = 1, slen
         mixingrulestring_s(n:n) = char(0)
         matrixstring_s(n:n) = char(0)
         inclusionstring_s(n:n) = char(0)
         hoststring_s(n:n) = char(0)
         hostmatrixstring_s(n:n) = char(0)
         hostinclusionstring_s(n:n) = char(0)
         mixingrulestring_g(n:n) = char(0)
         matrixstring_g(n:n) = char(0)
         inclusionstring_g(n:n) = char(0)
         hoststring_g(n:n) = char(0)
         hostmatrixstring_g(n:n) = char(0)
         hostinclusionstring_g(n:n) = char(0)
      enddo

      mixingrulestring_s = 'maxwellgarnett'
      hoststring_s = 'air'
      matrixstring_s = 'water'
      inclusionstring_s = 'spheroidal'
      hostmatrixstring_s = 'icewater'
      hostinclusionstring_s = 'spheroidal'

      mixingrulestring_g = 'maxwellgarnett'
      hoststring_g = 'air'
      matrixstring_g = 'water'
      inclusionstring_g = 'spheroidal'
      hostmatrixstring_g = 'icewater'
      hostinclusionstring_g = 'spheroidal'

      PI5 = 3.14159*3.14159*3.14159*3.14159*3.14159
      lamda4 = lamda_radar*lamda_radar*lamda_radar*lamda_radar
      m_w_0 = m_complex_water_ray (lamda_radar, 0.0d0)
      m_i_0 = m_complex_ice_maetzler (lamda_radar, 0.0d0)
      K_w = (ABS( (m_w_0*m_w_0 - 1.0) /(m_w_0*m_w_0 + 2.0) ))**2

      do n = 1, nrbins+1
         simpson(n) = 0.0d0
      enddo
      do n = 1, nrbins-1, 2
         simpson(n) = simpson(n) + basis(1)
         simpson(n+1) = simpson(n+1) + basis(2)
         simpson(n+2) = simpson(n+2) + basis(3)
      enddo

      !..Create bins of snow (from 100 microns up to 2 cm).
      xxDx(1) = 100.D-6
      xxDx(nrbins+1) = 0.02d0
      do n = 2, nrbins
         xxDx(n) = DEXP(DFLOAT(n-1)/DFLOAT(nrbins)                      &
     &                *DLOG(xxDx(nrbins+1)/xxDx(1)) +DLOG(xxDx(1)))
      enddo
      do n = 1, nrbins
         xxDs(n) = DSQRT(xxDx(n)*xxDx(n+1))
         xdts(n) = xxDx(n+1) - xxDx(n)
      enddo

      xxDx(1) = 100.D-6
      xxDx(nrbins+1) = 0.05d0
      do n = 2, nrbins
         xxDx(n) = DEXP(DFLOAT(n-1)/DFLOAT(nrbins)                      &
     &              *DLOG(xxDx(nrbins+1)/xxDx(1)) +DLOG(xxDx(1)))
      enddo
      do n = 1, nrbins
         xxDg(n) = DSQRT(xxDx(n)*xxDx(n+1))
         xdtg(n) = xxDx(n+1) - xxDx(n)
      enddo


C------ END of module_mp_radar.F -----------------------------------

      oams = 1./am_s
      obms = 1./bm_s
      ocms = oams**obms

      cge(1) = bm_g + 1.
      cge(2) = mu_g + 1.
      cge(3) = bm_g + mu_g + 1.
      cge(4) = bm_g*2. + mu_g + 1.
      cge(5) = bm_g*2. + mu_g + bv_g + 1.
      cge(6) = bm_g + mu_g + bv_g + 1.
      cge(7) = bm_g + mu_g + bv_g + 2.
      cge(8) = bm_g + mu_g + bv_g + 3.
      cge(9) = mu_g + bv_g + 3.
      cge(10) = mu_g + 2.
      cge(11) = 0.5*(bv_g + 5. + 2.*mu_g)
      cge(12) = 0.5*(bv_g + 5.) + mu_g
      do n = 1, 12
         cgg(n) = WGAMMA(cge(n))
      enddo
      oamg = 1./am_g
      obmg = 1./bm_g
      ocmg = oamg**obmg
      oge1 = 1./cge(1)
      ogg1 = 1./cgg(1)
      ogg2 = 1./cgg(2)
      ogg3 = 1./cgg(3)

      cre(1) = bm_r + 1.
      cre(2) = mu_r + 1.
      cre(3) = bm_r + mu_r + 1.
      cre(4) = bm_r*2. + mu_r + 1.
      !cre(5) = mu_r + bv_r + 1.
      !cre(6) = bm_r + mu_r + bv_r + 1.
      !cre(7) = bm_r*0.5 + mu_r + bv_r + 1.
      !cre(8) = bm_r + mu_r + bv_r + 3.
      !cre(9) = mu_r + bv_r + 3.
      !cre(10) = mu_r + 2.
      !cre(11) = 0.5*(bv_r + 5. + 2.*mu_r)
      !cre(12) = bm_r*0.5 + mu_r + 1.
      !cre(13) = bm_r*2. + mu_r + bv_r + 1.
      do n = 1, 13
         crg(n) = WGAMMA(cre(n))
      enddo
      obmr = 1./bm_r
      ore1 = 1./cre(1)
      org1 = 1./crg(1)
      org2 = 1./crg(2)
      org3 = 1./crg(3)

      cse(1) = bm_s + 1.
      cse(2) = bm_s + 2.
      cse(3) = bm_s*2.
      !cse(4) = bm_s + bv_s + 1.
      !cse(5) = bm_s*2. + bv_s + 1.
      !cse(6) = bm_s*2. + 1.
      !cse(7) = bm_s + mu_s + 1.
      !cse(8) = bm_s + mu_s + 2.
      !cse(9) = bm_s + mu_s + 3.
      !cse(10) = bm_s + mu_s + bv_s + 1.
      !cse(11) = bm_s*2. + mu_s + bv_s + 1.
      !cse(12) = bm_s*2. + mu_s + 1.
      !cse(13) = bv_s + 2.
      !cse(14) = bm_s + bv_s
      !cse(15) = mu_s + 1.
      !cse(16) = 1.0 + (1.0 + bv_s)/2.
      !cse(17) = cse(16) + mu_s + 1.
      !cse(18) = bv_s + mu_s + 3.

      do k = kts, kte
         dBZ(k) = -35.0
      enddo

!+---+-----------------------------------------------------------------+
!..Put column of data into local arrays.
!+---+-----------------------------------------------------------------+
      do k = kts, kte
         temp(k) = t1d(k)
         qv(k) = MAX(1.E-10, qv1d(k))
         pres(k) = p1d(k)
         rho(k) = 0.622*pres(k)/(R*temp(k)*(qv(k)+0.622))
         rhof(k) = SQRT(RHO_NOT/rho(k))
         rc(k) = MAX(R1, qc1d(k)*rho(k))
         if (qr1d(k) .gt. R1) then
            rr(k) = qr1d(k)*rho(k)
            nr(k) = MAX(R2, nr1d(k)*rho(k))
            lamr = (am_r*crg(3)*org2*nr(k)/rr(k))**obmr
            ilamr(k) = 1./lamr
            N0_r(k) = nr(k)*org2*lamr**cre(2)
            mvd_r(k) = (3.0 + mu_r + 0.672) * ilamr(k)
            L_qr(k) = .true.
         else
            rr(k) = R1
            nr(k) = R1
            mvd_r(k) = 50.E-6
            L_qr(k) = .false.
         endif
         if (qs1d(k) .gt. R2) then
            rs(k) = qs1d(k)*rho(k)
            L_qs(k) = .true.
         else
            rs(k) = R1
            L_qs(k) = .false.
         endif
         if (qg1d(k) .gt. R2) then
            rg(k) = qg1d(k)*rho(k)
            L_qg(k) = .true.
         else
            rg(k) = R1
            L_qg(k) = .false.
         endif
      enddo

!+---+-----------------------------------------------------------------+
!..Calculate y-intercept, slope, and useful moments for snow.
!+---+-----------------------------------------------------------------+
      do k = kts, kte
         tc0 = MIN(-0.1, temp(k)-273.15)
         smob(k) = rs(k)*oams

!..All other moments based on reference, 2nd moment.  If bm_s.ne.2,
!.. then we must compute actual 2nd moment and use as reference.
         if (bm_s.gt.(2.0-1.e-3) .and. bm_s.lt.(2.0+1.e-3)) then
            smo2(k) = smob(k)
         else
            loga_ = sa(1) + sa(2)*tc0 + sa(3)*bm_s                      &
     &         + sa(4)*tc0*bm_s + sa(5)*tc0*tc0                         &
     &         + sa(6)*bm_s*bm_s + sa(7)*tc0*tc0*bm_s                   &
     &         + sa(8)*tc0*bm_s*bm_s + sa(9)*tc0*tc0*tc0                &
     &         + sa(10)*bm_s*bm_s*bm_s
            a_ = 10.0**loga_
            b_ = sb(1) + sb(2)*tc0 + sb(3)*bm_s                         &
     &         + sb(4)*tc0*bm_s + sb(5)*tc0*tc0                         &
     &         + sb(6)*bm_s*bm_s + sb(7)*tc0*tc0*bm_s                   &
     &         + sb(8)*tc0*bm_s*bm_s + sb(9)*tc0*tc0*tc0                &
     &         + sb(10)*bm_s*bm_s*bm_s
            smo2(k) = (smob(k)/a_)**(1./b_)
         endif

!..Calculate bm_s+1 (th) moment.  Useful for diameter calcs.
         loga_ = sa(1) + sa(2)*tc0 + sa(3)*cse(1)                       &
     &         + sa(4)*tc0*cse(1) + sa(5)*tc0*tc0                       &
     &         + sa(6)*cse(1)*cse(1) + sa(7)*tc0*tc0*cse(1)             &
     &         + sa(8)*tc0*cse(1)*cse(1) + sa(9)*tc0*tc0*tc0            &
     &         + sa(10)*cse(1)*cse(1)*cse(1)
         a_ = 10.0**loga_
         b_ = sb(1)+ sb(2)*tc0 + sb(3)*cse(1) + sb(4)*tc0*cse(1)        &
     &        + sb(5)*tc0*tc0 + sb(6)*cse(1)*cse(1)                     &
     &        + sb(7)*tc0*tc0*cse(1) + sb(8)*tc0*cse(1)*cse(1)          &
     &        + sb(9)*tc0*tc0*tc0 + sb(10)*cse(1)*cse(1)*cse(1)
         smoc(k) = a_ * smo2(k)**b_

!..Calculate bm_s*2 (th) moment.  Useful for reflectivity.
         loga_ = sa(1) + sa(2)*tc0 + sa(3)*cse(3)                       &
     &         + sa(4)*tc0*cse(3) + sa(5)*tc0*tc0                       &
     &         + sa(6)*cse(3)*cse(3) + sa(7)*tc0*tc0*cse(3)             &
     &         + sa(8)*tc0*cse(3)*cse(3) + sa(9)*tc0*tc0*tc0            &
     &         + sa(10)*cse(3)*cse(3)*cse(3)
         a_ = 10.0**loga_
         b_ = sb(1)+ sb(2)*tc0 + sb(3)*cse(3) + sb(4)*tc0*cse(3)        &
     &        + sb(5)*tc0*tc0 + sb(6)*cse(3)*cse(3)                     &
     &        + sb(7)*tc0*tc0*cse(3) + sb(8)*tc0*cse(3)*cse(3)          &
     &        + sb(9)*tc0*tc0*tc0 + sb(10)*cse(3)*cse(3)*cse(3)
         smoz(k) = a_ * smo2(k)**b_
      enddo

!+---+-----------------------------------------------------------------+
!..Calculate y-intercept, slope values for graupel.
!+---+-----------------------------------------------------------------+

      N0_min = gonv_max
      do k = kte, kts, -1
         if (temp(k).lt.270.65 .and. L_qr(k) .and.                      &
     &       mvd_r(k).gt.100.E-6) then
            xslw1 = 4.01 + alog10(mvd_r(k))
         else
            xslw1 = 0.01
         endif
         ygra1 = 4.31 + alog10(max(5.E-5, rg(k)))
         zans1 = 3.1 + (100./(300.*xslw1*ygra1/                         &
     &                         (10./xslw1+1.+0.25*ygra1)+30.+10.*ygra1))
         N0_exp = 10.**(zans1)
         N0_exp = MAX(DBLE(gonv_min), MIN(N0_exp, DBLE(gonv_max)))
         N0_min = MIN(N0_exp, N0_min)
         N0_exp = N0_min
         lam_exp = (N0_exp*am_g*cgg(1)/rg(k))**oge1
         lamg = lam_exp * (cgg(3)*ogg2*ogg1)**obmg
         ilamg(k) = 1./lamg
         N0_g(k) = N0_exp/(cgg(2)*lam_exp) * lamg**cge(2)
      enddo

!+---+-----------------------------------------------------------------+
!..Locate K-level of start of melting (k_0 is level above).
!+---+-----------------------------------------------------------------+
      melti = .false.
      k_0 = kts
      do k = kte-1, kts, -1
         if ( (temp(k).gt.273.15) .and. L_qr(k)                         &
     &                            .and. (L_qs(k+1).or.L_qg(k+1)) ) then
            k_0 = MAX(k+1, k_0)
            melti=.true.
            goto 195
         endif
      enddo
 195  continue

!+---+-----------------------------------------------------------------+
!..Assume Rayleigh approximation at 10 cm wavelength. Rain (all temps)
!.. and non-water-coated snow and graupel when below freezing are
!.. simple. Integrations of m(D)*m(D)*N(D)*dD.
!+---+-----------------------------------------------------------------+

      do k = kts, kte
         ze_rain(k) = 1.e-22
         ze_snow(k) = 1.e-22
         ze_graupel(k) = 1.e-22
         if (L_qr(k)) ze_rain(k) = N0_r(k)*crg(4)*ilamr(k)**cre(4)
         if (L_qs(k)) ze_snow(k) = (0.176/0.93) * (6.0/PI)*(6.0/PI)     &
     &                           * (am_s/900.0)*(am_s/900.0)*smoz(k)
         if (L_qg(k)) ze_graupel(k) = (0.176/0.93) * (6.0/PI)*(6.0/PI)  &
     &                              * (am_g/900.0)*(am_g/900.0)         &
     &                              * N0_g(k)*cgg(4)*ilamg(k)**cge(4)
      enddo

!+---+-----------------------------------------------------------------+
!..Special case of melting ice (snow/graupel) particles.  Assume the
!.. ice is surrounded by the liquid water.  Fraction of meltwater is
!.. extremely simple based on amount found above the melting level.
!.. Uses code from Uli Blahak (rayleigh_soak_wetgraupel and supporting
!.. routines).
!+---+-----------------------------------------------------------------+

      if (.not. iiwarm .and. melti .and. k_0.ge.2) then
       do k = k_0-1, kts, -1

!..Reflectivity contributed by melting snow
          if (L_qs(k) .and. L_qs(k_0) ) then
           fmelt_s = MAX(0.05d0, MIN(1.0d0-rs(k)/rs(k_0), 0.99d0))
           eta = 0.d0
           oM3 = 1./smoc(k)
           M0 = (smob(k)*oM3)
           Mrat = smob(k)*M0*M0*M0
           slam1 = M0 * Lam0
           slam2 = M0 * Lam1
           do n = 1, nrbins
              x = am_s * xxDs(n)**bm_s
              call rayleigh_soak_wetgraupel (x, DBLE(ocms), DBLE(obms), &
     &              fmelt_s, melt_outside_s, m_w_0, m_i_0, lamda_radar, &
     &              CBACK, mixingrulestring_s, matrixstring_s,          &
     &              inclusionstring_s, hoststring_s,                    &
     &              hostmatrixstring_s, hostinclusionstring_s,          &
     &              lamda4,PI5)
              f_d = Mrat*(Kap0*DEXP(-slam1*xxDs(n))                     &
     &              + Kap1*(M0*xxDs(n))**mu_s * DEXP(-slam2*xxDs(n)))
              eta = eta + f_d * CBACK * simpson(n) * xdts(n)
           enddo
           ze_snow(k) = SNGL(lamda4 / (pi5 * K_w) * eta)
          endif

!..Reflectivity contributed by melting graupel

          if (L_qg(k) .and. L_qg(k_0) ) then
           fmelt_g = MAX(0.05d0, MIN(1.0d0-rg(k)/rg(k_0), 0.99d0))
           eta = 0.d0
           lamg = 1./ilamg(k)
           do n = 1, nrbins
              x = am_g * xxDg(n)**bm_g
              call rayleigh_soak_wetgraupel (x, DBLE(ocmg), DBLE(obmg), &
     &              fmelt_g, melt_outside_g, m_w_0, m_i_0, lamda_radar, &
     &              CBACK, mixingrulestring_g, matrixstring_g,          &
     &              inclusionstring_g, hoststring_g,                    &
     &              hostmatrixstring_g, hostinclusionstring_g,          &
     &              lamda4,PI5)
              f_d = N0_g(k)*xxDg(n)**mu_g * DEXP(-lamg*xxDg(n))
              eta = eta + f_d * CBACK * simpson(n) * xdtg(n)
           enddo
           ze_graupel(k) = SNGL(lamda4 / (pi5 * K_w) * eta)
          endif

       enddo
      endif

      do k = kte, kts, -1
         dBZ(k) = 10.*log10((ze_rain(k)+ze_snow(k)+ze_graupel(k))*1.d18)
      enddo


!..Reflectivity-weighted terminal velocity (snow, rain, graupel, mix).
!     do k = kte, kts, -1
!        vt_dBZ(k) = 1.E-3
!        if (rs(k).gt.R2) then
!         Mrat = smob(k) / smoc(k)
!         ils1 = 1./(Mrat*Lam0 + fv_s)
!         ils2 = 1./(Mrat*Lam1 + fv_s)
!         t1_vts = Kap0*csg(5)*ils1**cse(5)
!         t2_vts = Kap1*Mrat**mu_s*csg(11)*ils2**cse(11)
!         ils1 = 1./(Mrat*Lam0)
!         ils2 = 1./(Mrat*Lam1)
!         t3_vts = Kap0*csg(6)*ils1**cse(6)
!         t4_vts = Kap1*Mrat**mu_s*csg(12)*ils2**cse(12)
!         vts_dbz_wt = rhof(k)*av_s * (t1_vts+t2_vts)/(t3_vts+t4_vts)
!         if (temp(k).ge.273.15 .and. temp(k).lt.275.15) then
!            vts_dbz_wt = vts_dbz_wt*1.5
!         elseif (temp(k).ge.275.15) then
!            vts_dbz_wt = vts_dbz_wt*2.0
!         endif
!        else
!         vts_dbz_wt = 1.E-3
!        endif

!        if (rr(k).gt.R1) then
!         lamr = 1./ilamr(k)
!         vtr_dbz_wt = rhof(k)*av_r*crg(13)*(lamr+fv_r)**(-cre(13))      &
!    &               / (crg(4)*lamr**(-cre(4)))
!        else
!         vtr_dbz_wt = 1.E-3
!        endif

!        if (rg(k).gt.R2) then
!         lamg = 1./ilamg(k)
!         vtg_dbz_wt = rhof(k)*av_g*cgg(5)*lamg**(-cge(5))               &
!    &               / (cgg(4)*lamg**(-cge(4)))
!        else
!         vtg_dbz_wt = 1.E-3
!        endif

!        vt_dBZ(k) = (vts_dbz_wt*ze_snow(k) + vtr_dbz_wt*ze_rain(k)      &
!    &                + vtg_dbz_wt*ze_graupel(k))                        &
!    &                / (ze_rain(k)+ze_snow(k)+ze_graupel(k))
!     enddo

      end subroutine calc_refl10cm

C#######################################################################

      subroutine rayleigh_soak_wetgraupel (x_g, a_geo, b_geo, fmelt,    &
     &               meltratio_outside, m_w, m_i, lambda, C_back,       &
     &               mixingrule,matrix,inclusion,                       &
     &               host,hostmatrix,hostinclusion,lamda4,PI5)

      IMPLICIT NONE

      DOUBLE PRECISION, INTENT(in) :: PI5, lamda4
      DOUBLE PRECISION, INTENT(in):: x_g, a_geo, b_geo, fmelt, lambda,  &
     &                                 meltratio_outside
      DOUBLE PRECISION, INTENT(out):: C_back
      COMPLEX*16, INTENT(in):: m_w, m_i
      CHARACTER(len=*), INTENT(in):: mixingrule, matrix, inclusion,     &
     &                               host, hostmatrix, hostinclusion

      COMPLEX*16:: m_core, m_air
      DOUBLE PRECISION:: D_large, D_g, rhog, x_w, xw_a, fm, fmgrenz,    &
     &                   volg, vg, volair, volice, volwater,            &
     &                   meltratio_outside_grenz, mra
      INTEGER:: error
      DOUBLE PRECISION, PARAMETER:: PIx=3.1415926535897932384626434d0

      COMPLEX*16 :: m_complex_water_ray, get_m_mix_nested

!     refractive index of air:
      m_air = (1.0d0,0.0d0)

!     Limiting the degree of melting --- for safety:
      fm = DMAX1(DMIN1(fmelt, 1.0d0), 0.0d0)
!     Limiting the ratio of (melting on outside)/(melting on inside):
      mra = DMAX1(DMIN1(meltratio_outside, 1.0d0), 0.0d0)

!    ! The relative portion of meltwater melting at outside should increase
!    ! from the given input value (between 0 and 1)
!    ! to 1 as the degree of melting approaches 1,
!    ! so that the melting particle "converges" to a water drop.
!    ! Simplest assumption is linear:
      mra = mra + (1.0d0-mra)*fm

      x_w = x_g * fm

      D_g = a_geo * x_g**b_geo

      if (D_g .ge. 1d-12) then

       vg = PIx/6. * D_g**3
       rhog = DMAX1(DMIN1(x_g / vg, 900.0d0), 10.0d0)
       vg = x_g / rhog

       meltratio_outside_grenz = 1.0d0 - rhog / 1000.

       if (mra .le. meltratio_outside_grenz) then
        !..In this case, it cannot happen that, during melting, all the
        !.. air inclusions within the ice particle get filled with
        !.. meltwater. This only happens at the end of all melting.
        volg = vg * (1.0d0 - mra * fm)

       else
        !..In this case, at some melting degree fm, all the air
        !.. inclusions get filled with meltwater.
        fmgrenz=(900.0-rhog)/(mra*900.0-rhog+900.0*rhog/1000.)

        if (fm .le. fmgrenz) then
         !.. not all air pockets are filled:
         volg = (1.0 - mra * fm) * vg
        else
         !..all air pockets are filled with meltwater, now the
         !.. entire ice sceleton melts homogeneously:
         volg = (x_g - x_w) / 900.0 + x_w / 1000.
        endif

       endif

       D_large  = (6.0 / PIx * volg) ** (1./3.)
       volice = (x_g - x_w) / (volg * 900.0)
       volwater = x_w / (1000. * volg)
       volair = 1.0 - volice - volwater

       !..complex index of refraction for the ice-air-water mixture
       !.. of the particle:
       m_core = get_m_mix_nested (m_air, m_i, m_w, volair, volice,      &
     &                   volwater, mixingrule, host, matrix, inclusion, &
     &                   hostmatrix, hostinclusion, error)
       if (error .ne. 0) then
        C_back = 0.0d0
        return
       endif

       !..Rayleigh-backscattering coefficient of melting particle:
       C_back = (ABS((m_core**2-1.0d0)/(m_core**2+2.0d0)))**2           &
     &           * PI5 * D_large**6 / lamda4

      else
        C_back = 0.0d0
      endif

      end subroutine rayleigh_soak_wetgraupel

C#######################################################################

      COMPLEX*16 FUNCTION m_complex_water_ray(lambda,T)

c      Complex refractive Index of Water as function of Temperature T
c      [deg C] and radar wavelength lambda [m]; valid for
c      lambda in [0.001,1.0] m; T in [-10.0,30.0] deg C
c      after Ray (1972)

      IMPLICIT NONE
      DOUBLE PRECISION, INTENT(IN):: T,lambda
      DOUBLE PRECISION :: epsinf,epss,epsr,epsi
      DOUBLE PRECISION :: alpha,lambdas,sigma,nenner
      COMPLEX*16, PARAMETER :: i = (0d0,1d0)
      DOUBLE PRECISION, PARAMETER :: PIx=3.1415926535897932384626434d0

      epsinf  = 5.27137d0 + 0.02164740d0 * T - 0.00131198d0 * T*T
      epss    = 78.54d+0 * (1.0 - 4.579d-3 * (T - 25.0)                 &
     &         + 1.190d-5 * (T - 25.0)*(T - 25.0)                        &
     &         - 2.800d-8 * (T - 25.0)*(T - 25.0)*(T - 25.0))
      alpha   = -16.8129d0/(T+273.16) + 0.0609265d0
      lambdas = 0.00033836d0 * exp(2513.98d0/(T+273.16)) * 1e-2

      nenner = 1.d0+2.d0*(lambdas/lambda)**(1d0-alpha)                  &
     &                              *sin(alpha*PIx*0.5)                 &
     &         + (lambdas/lambda)**(2d0-2d0*alpha)
      epsr = epsinf + ((epss-epsinf) * ((lambdas/lambda)**(1d0-alpha)   &
     &       * sin(alpha*PIx*0.5)+1d0)) / nenner
      epsi = ((epss-epsinf) * ((lambdas/lambda)**(1d0-alpha)            &
     &       * cos(alpha*PIx*0.5)+0d0)) / nenner                        &
     &       + lambda*1.25664/1.88496

      m_complex_water_ray = SQRT(CMPLX(epsr,-epsi))

      END FUNCTION m_complex_water_ray

C#######################################################################

      COMPLEX*16 FUNCTION m_complex_ice_maetzler(lambda,T)

!      complex refractive index of ice as function of Temperature T
!      [deg C] and radar wavelength lambda [m]; valid for
!      lambda in [0.0001,30] m; T in [-250.0,0.0] C
!      Original comment from the Matlab-routine of Prof. Maetzler:
!      Function for calculating the relative permittivity of pure ice in
!      the microwave region, according to C. Maetzler, "Microwave
!      properties of ice and snow", in B. Schmitt et al. (eds.) Solar
!      System Ices, Astrophys. and Space Sci. Library, Vol. 227, Kluwer
!      Academic Publishers, Dordrecht, pp. 241-257 (1998). Input:
!      TK = temperature (K), range 20 to 273.15
!      f = frequency in GHz, range 0.01 to 3000

      IMPLICIT NONE
      DOUBLE PRECISION, INTENT(IN):: T,lambda
      DOUBLE PRECISION:: f,c,TK,B1,B2,b,deltabeta,betam,beta,theta,alfa

      c = 2.99d8
      TK = T + 273.16
      f = c / lambda * 1d-9

      B1 = 0.0207
      B2 = 1.16d-11
      b = 335.0d0
      deltabeta = EXP(-10.02 + 0.0364*(TK-273.16))
      betam = (B1/TK) * ( EXP(b/TK) / ((EXP(b/TK)-1)**2) ) + B2*f*f
      beta = betam + deltabeta
      theta = 300. / TK - 1.
      alfa = (0.00504d0 + 0.0062d0*theta) * EXP(-22.1d0*theta)
      m_complex_ice_maetzler = 3.1884 + 9.1e-4*(TK-273.16)
      m_complex_ice_maetzler = m_complex_ice_maetzler                   &
     &                        + CMPLX(0.0d0, (alfa/f + beta*f))
      m_complex_ice_maetzler = SQRT(CONJG(m_complex_ice_maetzler))

      END FUNCTION m_complex_ice_maetzler

!+---+-----------------------------------------------------------------+

      COMPLEX*16 FUNCTION get_m_mix (m_a, m_i, m_w, volair, volice,     &
     &                volwater, mixingrule, matrix, inclusion, error)

      IMPLICIT NONE

      DOUBLE PRECISION, INTENT(in):: volice, volair, volwater
      COMPLEX*16, INTENT(in):: m_a, m_i, m_w
      CHARACTER(len=*), INTENT(in):: mixingrule, matrix, inclusion
      INTEGER, INTENT(out):: error

      COMPLEX*16 m_complex_maxwellgarnett


      error = 0
      get_m_mix = CMPLX(1.0d0,0.0d0)

      if (mixingrule .eq. 'maxwellgarnett') then
       if (matrix .eq. 'ice') then
        get_m_mix = m_complex_maxwellgarnett(volice, volair, volwater,  &
     &                       m_i, m_a, m_w, inclusion, error)
       elseif (matrix .eq. 'water') then
        get_m_mix = m_complex_maxwellgarnett(volwater, volair, volice,  &
     &                       m_w, m_a, m_i, inclusion, error)
       elseif (matrix .eq. 'air') then
        get_m_mix = m_complex_maxwellgarnett(volair, volwater, volice,  &
     &                       m_a, m_w, m_i, inclusion, error)
       else
!        write(radar_debug,*) 'GET_M_MIX: unknown matrix: ', matrix
!        CALL wrf_debug(150, radar_debug)
        error = 1
       endif

      else
!       write(radar_debug,*) 'GET_M_MIX: unknown mixingrule: ', mixingrule
!       CALL wrf_debug(150, radar_debug)
       error = 2
      endif

!      if (error .ne. 0) then
!      write(radar_debug,*) 'GET_M_MIX: error encountered'
!       CALL wrf_debug(150, radar_debug)
!      endif

      END FUNCTION get_m_mix

!+---+-----------------------------------------------------------------+

      complex*16 function get_m_mix_nested (m_a, m_i, m_w, volair,      &
     &                 volice, volwater, mixingrule, host, matrix,      &
     &                 inclusion, hostmatrix, hostinclusion, cumulerror)

      IMPLICIT NONE

      DOUBLE PRECISION, INTENT(in):: volice, volair, volwater
      COMPLEX*16, INTENT(in):: m_a, m_i, m_w
      CHARACTER(len=*), INTENT(in):: mixingrule, host, matrix,          &
     &                 inclusion, hostmatrix, hostinclusion
      INTEGER, INTENT(out):: cumulerror

      DOUBLE PRECISION:: vol1, vol2
      COMPLEX*16:: mtmp
      INTEGER:: error

      COMPLEX*16  get_m_mix


      !..Folded: ( (m1 + m2) + m3), where m1,m2,m3 could each be
      !.. air, ice, or water

      cumulerror = 0
      get_m_mix_nested = CMPLX(1.0d0,0.0d0)

      if (host .eq. 'air') then

       if (matrix .eq. 'air') then
        !write(radar_debug,*) 'GET_M_MIX_NESTED: bad matrix: ', matrix
        !CALL wrf_debug(150, radar_debug)
        cumulerror = cumulerror + 1
       else
        vol1 = volice / MAX(volice+volwater,1d-10)
        vol2 = 1.0d0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, 0.0d0, vol1, vol2,             &
     &                     mixingrule, matrix, inclusion, error)
        cumulerror = cumulerror + error

        if (hostmatrix .eq. 'air') then
         get_m_mix_nested = get_m_mix (m_a, mtmp, 2.0*m_a,              &
     &                     volair, (1.0d0-volair), 0.0d0, mixingrule,   &
     &                     hostmatrix, hostinclusion, error)
         cumulerror = cumulerror + error
        elseif (hostmatrix .eq. 'icewater') then
         get_m_mix_nested = get_m_mix (m_a, mtmp, 2.0*m_a,              &
     &                    volair, (1.0d0-volair), 0.0d0, mixingrule,    &
     &                    'ice', hostinclusion, error)
         cumulerror = cumulerror + error
        else
!         write(radar_debug,*) 'GET_M_MIX_NESTED: bad hostmatrix: ',     &
!     &                      hostmatrix
!         CALL wrf_debug(150, radar_debug)
         cumulerror = cumulerror + 1
        endif
       endif

      elseif (host .eq. 'ice') then

       if (matrix .eq. 'ice') then
!        write(radar_debug,*) 'GET_M_MIX_NESTED: bad matrix: ', matrix
!        CALL wrf_debug(150, radar_debug)
        cumulerror = cumulerror + 1
       else
        vol1 = volair / MAX(volair+volwater,1d-10)
        vol2 = 1.0d0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, vol1, 0.0d0, vol2,             &
     &                    mixingrule, matrix, inclusion, error)
        cumulerror = cumulerror + error

        if (hostmatrix .eq. 'ice') then
         get_m_mix_nested = get_m_mix (mtmp, m_i, 2.0*m_a,              &
     &                    (1.0d0-volice), volice, 0.0d0, mixingrule,    &
     &                   hostmatrix, hostinclusion, error)
         cumulerror = cumulerror + error
        elseif (hostmatrix .eq. 'airwater') then
         get_m_mix_nested = get_m_mix (mtmp, m_i, 2.0*m_a,              &
     &                    (1.0d0-volice), volice, 0.0d0, mixingrule,    &
     &                    'air', hostinclusion, error)
         cumulerror = cumulerror + error
        else
!         write(radar_debug,*) 'GET_M_MIX_NESTED: bad hostmatrix: ',     &
!     &                      hostmatrix
!         CALL wrf_debug(150, radar_debug)
         cumulerror = cumulerror + 1
        endif
       endif

      elseif (host .eq. 'water') then

       if (matrix .eq. 'water') then
!        write(radar_debug,*) 'GET_M_MIX_NESTED: bad matrix: ', matrix
!        CALL wrf_debug(150, radar_debug)
        cumulerror = cumulerror + 1
       else
        vol1 = volair / MAX(volice+volair,1d-10)
        vol2 = 1.0d0 - vol1
        mtmp = get_m_mix (m_a, m_i, m_w, vol1, vol2, 0.0d0,             &
     &                   mixingrule, matrix, inclusion, error)
        cumulerror = cumulerror + error

        if (hostmatrix .eq. 'water') then
         get_m_mix_nested = get_m_mix (2*m_a, mtmp, m_w,                &
     &                   0.0d0, (1.0d0-volwater), volwater, mixingrule, &
     &                   hostmatrix, hostinclusion, error)
         cumulerror = cumulerror + error
        elseif (hostmatrix .eq. 'airice') then
         get_m_mix_nested = get_m_mix (2*m_a, mtmp, m_w,                &
     &                   0.0d0, (1.0d0-volwater), volwater, mixingrule, &
     &                   'ice', hostinclusion, error)
         cumulerror = cumulerror + error
        else
!         write(radar_debug,*) 'GET_M_MIX_NESTED: bad hostmatrix: ',     &
!     &                      hostmatrix
!         CALL wrf_debug(150, radar_debug)
         cumulerror = cumulerror + 1
        endif
       endif

      elseif (host .eq. 'none') then

       get_m_mix_nested = get_m_mix (m_a, m_i, m_w,                     &
     &                  volair, volice, volwater, mixingrule,           &
     &                  matrix, inclusion, error)
       cumulerror = cumulerror + error

      else
!       write(radar_debug,*) 'GET_M_MIX_NESTED: unknown matrix: ', host
!       CALL wrf_debug(150, radar_debug)
       cumulerror = cumulerror + 1
      endif

      IF (cumulerror .ne. 0) THEN
!       write(radar_debug,*) 'GET_M_MIX_NESTED: error encountered'
!       CALL wrf_debug(150, radar_debug)
       get_m_mix_nested = CMPLX(1.0d0,0.0d0)
      endif

      end function get_m_mix_nested

!+---+-----------------------------------------------------------------+

      COMPLEX*16 FUNCTION m_complex_maxwellgarnett(vol1, vol2, vol3,    &
     &                m1, m2, m3, inclusion, error)

      IMPLICIT NONE

      COMPLEX*16 :: m1, m2, m3
      DOUBLE PRECISION :: vol1, vol2, vol3
      CHARACTER(len=*) :: inclusion

      COMPLEX*16 :: beta2, beta3, m1t, m2t, m3t
      INTEGER, INTENT(out) :: error

      error = 0

      if (DABS(vol1+vol2+vol3-1.0d0) .gt. 1d-6) then
!       write(radar_debug,*) 'M_COMPLEX_MAXWELLGARNETT: sum of the ',       &
!              'partial volume fractions is not 1...ERROR'
!       CALL wrf_debug(150, radar_debug)
       m_complex_maxwellgarnett=CMPLX(-999.99d0,-999.99d0)
       error = 1
       return
      endif

      m1t = m1**2
      m2t = m2**2
      m3t = m3**2

      if (inclusion .eq. 'spherical') then
       beta2 = 3.0d0*m1t/(m2t+2.0d0*m1t)
       beta3 = 3.0d0*m1t/(m3t+2.0d0*m1t)
      elseif (inclusion .eq. 'spheroidal') then
       beta2 = 2.0d0*m1t/(m2t-m1t) * (m2t/(m2t-m1t)*LOG(m2t/m1t)-1.0d0)
       beta3 = 2.0d0*m1t/(m3t-m1t) * (m3t/(m3t-m1t)*LOG(m3t/m1t)-1.0d0)
      else
!       write(radar_debug,*) 'M_COMPLEX_MAXWELLGARNETT: ',                  &
!                         'unknown inclusion: ', inclusion
!       CALL wrf_debug(150, radar_debug)
       m_complex_maxwellgarnett=DCMPLX(-999.99d0,-999.99d0)
       error = 1
       return
      endif

      m_complex_maxwellgarnett =                                        &
     &  SQRT(((1.0d0-vol2-vol3)*m1t + vol2*beta2*m2t + vol3*beta3*m3t) / &
     &  (1.0d0-vol2-vol3+vol2*beta2+vol3*beta3))

      END FUNCTION m_complex_maxwellgarnett

C  (C) Copr. 1986-92 Numerical Recipes Software 2.02
C+---+-----------------------------------------------------------------+
      REAL FUNCTION GAMMLN(XX)
!     --- RETURNS THE VALUE LN(GAMMA(XX)) FOR XX > 0.
      IMPLICIT NONE
      REAL, INTENT(IN):: XX
      DOUBLE PRECISION, PARAMETER:: STP = 2.5066282746310005D0
      DOUBLE PRECISION, DIMENSION(6), PARAMETER::                       &
     &         COF = (/76.18009172947146D0, -86.50532032941677D0,       &
     &                  24.01409824083091D0, -1.231739572450155D0,      &
     &                 .1208650973866179D-2, -.5395239384953D-5/)
      DOUBLE PRECISION:: SER,TMP,X,Y
      INTEGER:: J

      X=XX
      Y=X
      TMP=X+5.5D0
      TMP=(X+0.5D0)*LOG(TMP)-TMP
      SER=1.000000000190015D0
      DO J=1,6
        Y=Y+1.D0
        SER=SER+COF(J)/Y
      END DO
      GAMMLN=TMP+LOG(STP*SER/X)
      END FUNCTION GAMMLN

C+---+-----------------------------------------------------------------+
      REAL FUNCTION WGAMMA(y)

      IMPLICIT NONE
      REAL, INTENT(IN):: y
      REAL :: GAMMLN

      WGAMMA = EXP(GAMMLN(y))

      END FUNCTION WGAMMA
