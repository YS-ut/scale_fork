!-------------------------------------------------------------------------------
!> module ATMOSPHERE / Physics Surface fluxes
!!
!! @par Description
!!          Flux from/to bottom boundary of atmosphere (surface)
!!
!! @author Team SCALE
!!
!<
!-------------------------------------------------------------------------------
#include "scalelib.h"
module mod_atmos_phy_sf_driver
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_io
  use scale_prof
  use scale_atmos_grid_cartesC_index
  use scale_tracer
  use scale_cpl_sfc_index
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: ATMOS_PHY_SF_driver_setup
  public :: ATMOS_PHY_SF_driver_calc_tendency

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private procedure
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private parameters & variables
  !
  integer :: hist_uabs10, hist_u10m, hist_v10m
  integer :: hist_t2, hist_q2, hist_rh2
  integer :: hist_mslp

  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine ATMOS_PHY_SF_driver_setup
    use scale_prc, only: &
       PRC_abort
    use scale_atmos_phy_sf_bulk, only: &
       ATMOS_PHY_SF_bulk_setup
    use scale_atmos_phy_sf_const, only: &
       ATMOS_PHY_SF_const_setup
    use scale_file_history, only: &
       FILE_HISTORY_reg
    use mod_atmos_admin, only: &
       ATMOS_PHY_SF_TYPE, &
       ATMOS_sw_phy_sf
    use mod_atmos_phy_sf_vars, only: &
       SFC_Z0M   => ATMOS_PHY_SF_SFC_Z0M,   &
       SFC_Z0H   => ATMOS_PHY_SF_SFC_Z0H,   &
       SFC_Z0E   => ATMOS_PHY_SF_SFC_Z0E,   &
       SFLX_MW   => ATMOS_PHY_SF_SFLX_MW,   &
       SFLX_MU   => ATMOS_PHY_SF_SFLX_MU,   &
       SFLX_MV   => ATMOS_PHY_SF_SFLX_MV,   &
       SFLX_SH   => ATMOS_PHY_SF_SFLX_SH,   &
       SFLX_LH   => ATMOS_PHY_SF_SFLX_LH,   &
       SFLX_SHEX => ATMOS_PHY_SF_SFLX_SHEX, &
       SFLX_QVEX => ATMOS_PHY_SF_SFLX_QVEX, &
       SFLX_QTRC => ATMOS_PHY_SF_SFLX_QTRC, &
       SFLX_ENGI => ATMOS_PHY_SF_SFLX_ENGI, &
       Ustar     => ATMOS_PHY_SF_Ustar,     &
       Tstar     => ATMOS_PHY_SF_Tstar,     &
       Qstar     => ATMOS_PHY_SF_Qstar,     &
       Wstar     => ATMOS_PHY_SF_Wstar,     &
       RLmo      => ATMOS_PHY_SF_RLmo
    use mod_cpl_admin, only: &
       CPL_sw
    implicit none
    !---------------------------------------------------------------------------

    LOG_NEWLINE
    LOG_INFO("ATMOS_PHY_SF_driver_setup",*) 'Setup'

    if ( ATMOS_sw_phy_sf ) then

       if ( CPL_sw ) then
          LOG_INFO("ATMOS_PHY_SF_driver_setup",*) 'Coupler is enabled.'
       else
          ! setup library component
          select case( ATMOS_PHY_SF_TYPE )
          case ( 'BULK' )
             call ATMOS_PHY_SF_bulk_setup
          case ( 'CONST' )
             call ATMOS_PHY_SF_const_setup
          case default
             LOG_ERROR("ATMOS_PHY_SF_driver_setup",*) 'invalid Surface flux type(', trim(ATMOS_PHY_SF_TYPE), '). CHECK!'
             call PRC_abort
          end select
       endif

    else

       LOG_INFO("ATMOS_PHY_SF_driver_setup",*) 'this component is never called.'
       LOG_INFO("ATMOS_PHY_SF_driver_setup",*) 'surface fluxes are set to zero.'
       !$acc kernels
       SFLX_MW  (:,:) = 0.0_RP
       SFLX_MU  (:,:) = 0.0_RP
       SFLX_MV  (:,:) = 0.0_RP
       SFLX_SH  (:,:) = 0.0_RP
       SFLX_LH  (:,:) = 0.0_RP
       SFLX_SHEX(:,:) = 0.0_RP
       SFLX_QVEX(:,:) = 0.0_RP
       Ustar    (:,:) = 0.0_RP
       Tstar    (:,:) = 0.0_RP
       Qstar    (:,:) = 0.0_RP
       Wstar    (:,:) = 0.0_RP
       RLmo     (:,:) = 0.0_RP
       !$acc end kernels
       LOG_INFO("ATMOS_PHY_SF_driver_setup",*) 'SFC_TEMP, SFC_albedo is set in ATMOS_PHY_SF_vars.'

    endif

    !$acc kernels
    SFLX_QTRC(:,:,:) = 0.0_RP
    SFLX_ENGI(:,:)   = 0.0_RP
    !$acc end kernels

    call FILE_HISTORY_reg( 'Uabs10', '10m absolute wind',         'm/s'  , hist_uabs10, ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'U10m',   '10m eastward wind',         'm/s'  , hist_u10m,   ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'V10m',   '10m northward wind',        'm/s'  , hist_v10m,   ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'T2',     '2m air temperature',        'K'    , hist_t2,     ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'Q2',     '2m specific humidity',      'kg/kg', hist_q2,     ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'RH2',    '2m relative humidity',      '%',     hist_rh2,    ndims=2, fill_halo=.true. )
    call FILE_HISTORY_reg( 'MSLP',   'mean sea-level pressure',   'Pa'   , hist_mslp,   ndims=2, fill_halo=.true., standard_name='air_pressure_at_mean_sea_level' )

    return
  end subroutine ATMOS_PHY_SF_driver_setup

  !-----------------------------------------------------------------------------
  !> calculation tendency
  subroutine ATMOS_PHY_SF_driver_calc_tendency( update_flag )
    use scale_const, only: &
       UNDEF  => CONST_UNDEF, &
       PRE00  => CONST_PRE00, &
       Rdry   => CONST_Rdry,  &
       Rvap   => CONST_Rvap,  &
       CPdry  => CONST_CPdry, &
       CPvap  => CONST_CPvap, &
       EPSTvap => CONST_EPSTvap
    use scale_atmos_grid_cartesC_real, only: &
       CZ => ATMOS_GRID_CARTESC_REAL_CZ, &
       FZ => ATMOS_GRID_CARTESC_REAL_FZ, &
       Z1 => ATMOS_GRID_CARTESC_REAL_Z1, &
       ATMOS_GRID_CARTESC_REAL_AREA, &
       ATMOS_GRID_CARTESC_REAL_TOTAREA
    use scale_topography, only: &
       TanSL_X => TOPOGRAPHY_TanSL_X, &
       TanSL_Y => TOPOGRAPHY_TanSL_Y
    use scale_time, only: &
       dt_SF => TIME_DTSEC_ATMOS_PHY_SF
    use scale_statistics, only: &
       STATISTICS_checktotal, &
       STATISTICS_total
    use scale_atmos_bottom, only: &
       BOTTOM_estimate => ATMOS_BOTTOM_estimate
    use scale_atmos_hydrometeor, only: &
       ATMOS_HYDROMETEOR_dry, &
       LHV, &
       I_QV
    use scale_atmos_phy_sf_bulk, only: &
       ATMOS_PHY_SF_bulk_flux
    use scale_atmos_phy_sf_const, only: &
       ATMOS_PHY_SF_const_flux
    use scale_bulkflux, only: &
       BULKFLUX_diagnose_scales
    use mod_atmos_admin, only: &
       ATMOS_PHY_SF_TYPE
    use mod_atmos_vars, only: &
       DENS   => DENS_av, &
       RHOT   => RHOT_av, &
       POTT,              &
       TEMP,              &
       PRES,              &
       W,                 &
       U,                 &
       V,                 &
       QV,                &
       CPtot,             &
       CVtot,             &
       DENS_t => DENS_tp, &
       MOMZ_t => MOMZ_tp, &
       RHOU_t => RHOU_tp, &
       RHOV_t => RHOV_tp, &
       RHOH   => RHOH_p,  &
       RHOQ_t => RHOQ_tp
    use mod_atmos_phy_rd_vars, only: &
       SFLX_LW_dn => ATMOS_PHY_RD_SFLX_LW_dn, &
       SFLX_SW_dn => ATMOS_PHY_RD_SFLX_SW_dn
    use mod_atmos_phy_bl_vars, only: &
       PBL_Zi => ATMOS_PHY_BL_Zi
    use mod_atmos_phy_sf_vars, only: &
       DENS_t_SF => ATMOS_PHY_SF_DENS_t,    &
       MOMZ_t_SF => ATMOS_PHY_SF_MOMZ_t,    &
       RHOU_t_SF => ATMOS_PHY_SF_RHOU_t,    &
       RHOV_t_SF => ATMOS_PHY_SF_RHOV_t,    &
       RHOH_SF   => ATMOS_PHY_SF_RHOH,      &
       RHOQ_t_SF => ATMOS_PHY_SF_RHOQ_t,    &
       SFC_DENS  => ATMOS_PHY_SF_SFC_DENS,  &
       SFC_PRES  => ATMOS_PHY_SF_SFC_PRES,  &
       SFC_TEMP  => ATMOS_PHY_SF_SFC_TEMP,  &
       SFC_Z0M   => ATMOS_PHY_SF_SFC_Z0M,   &
       SFC_Z0H   => ATMOS_PHY_SF_SFC_Z0H,   &
       SFC_Z0E   => ATMOS_PHY_SF_SFC_Z0E,   &
       SFLX_MW   => ATMOS_PHY_SF_SFLX_MW,   &
       SFLX_MU   => ATMOS_PHY_SF_SFLX_MU,   &
       SFLX_MV   => ATMOS_PHY_SF_SFLX_MV,   &
       SFLX_SH   => ATMOS_PHY_SF_SFLX_SH,   &
       SFLX_LH   => ATMOS_PHY_SF_SFLX_LH,   &
       SFLX_SHEX => ATMOS_PHY_SF_SFLX_SHEX, &
       SFLX_QVEX => ATMOS_PHY_SF_SFLX_QVEX, &
       SFLX_QTRC => ATMOS_PHY_SF_SFLX_QTRC, &
       SFLX_ENGI => ATMOS_PHY_SF_SFLX_ENGI, &
       Ustar     => ATMOS_PHY_SF_Ustar,     &
       Tstar     => ATMOS_PHY_SF_Tstar,     &
       Qstar     => ATMOS_PHY_SF_Qstar,     &
       Wstar     => ATMOS_PHY_SF_Wstar,     &
       RLmo      => ATMOS_PHY_SF_RLmo,      &
       U10       => ATMOS_PHY_SF_U10,       &
       V10       => ATMOS_PHY_SF_V10,       &
       T2        => ATMOS_PHY_SF_T2,        &
       Q2        => ATMOS_PHY_SF_Q2
    use mod_cpl_admin, only: &
       CPL_sw
    implicit none

    logical, intent(in) :: update_flag

    real(RP) :: ATM_W   (IA,JA)
    real(RP) :: ATM_U   (IA,JA)
    real(RP) :: ATM_V   (IA,JA)
    real(RP) :: ATM_DENS(IA,JA)
    real(RP) :: ATM_TEMP(IA,JA)
    real(RP) :: ATM_PRES(IA,JA)
    real(RP) :: ATM_QV  (IA,JA)
    real(RP) :: SFC_POTV(IA,JA)
    real(RP) :: SFLX_SH2(IA,JA)
    real(RP) :: SFLX_QV (IA,JA)
    real(RP) :: CP_t, CV_t
    real(RP) :: ENGI_t
    real(RP) :: rdz
    real(RP) :: work
    real(RP) :: kappa

    integer  :: i, j, iq
    !---------------------------------------------------------------------------

    if ( update_flag ) then

       !$acc data create(ATM_DENS,ATM_TEMP,ATM_PRES,SFLX_QV)

       ! update surface density, surface pressure
       call BOTTOM_estimate( KA, KS,  KE, IA, IS, IE, JA, JS, JE, &
                             DENS(:,:,:), PRES(:,:,:), QV(:,:,:), & ! [IN]
                             SFC_TEMP(:,:),                       & ! [IN]
                             FZ(:,:,:),                           & ! [IN]
                             SFC_DENS(:,:), SFC_PRES(:,:)         ) ! [OUT]

       !$omp parallel do
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          ATM_DENS(i,j) = DENS(KS,i,j)
          ATM_TEMP(i,j) = TEMP(KS,i,j)
          ATM_PRES(i,j) = PRES(KS,i,j)
       end do
       end do
       !$acc end kernels

       if ( CPL_sw ) then

          !$acc data create(SFLX_SH2)

          !$omp parallel do
          !$acc kernels
          do j = JS, JE
          do i = IS, IE
             SFLX_SH2(i,j) = SFLX_SH(i,j) - SFLX_SHEX(i,j)
          end do
          end do
          !$acc end kernels

          if ( ATMOS_HYDROMETEOR_dry ) then
             !$omp parallel do
             !$acc kernels
             do j = JS, JE
             do i = IS, IE
                SFLX_QV(i,j) = 0.0_RP
                SFC_POTV(i,j) = SFC_TEMP(i,j) * ( PRE00 / SFC_PRES(i,j) )**( Rdry / CPdry )
             end do
             end do
             !$acc end kernels
          else
             !$omp parallel do private(kappa)
             !$acc kernels
             do j = JS, JE
             do i = IS, IE
                SFLX_QV(i,j) = SFLX_QTRC(i,j,I_QV) - SFLX_QVEX(i,j)
                kappa = ( Rdry + ( Rvap - Rdry ) * QV(KS,i,j) ) &
                     / ( CPdry + ( CPvap - CPdry ) * QV(KS,i,j) )
                SFC_POTV(i,j) = SFC_TEMP(i,j) * ( PRE00 / SFC_PRES(i,j) )**kappa &
                              * ( 1.0_RP + EPSTvap * QV(KS,i,j) )
             end do
             end do
             !$acc end kernels
          end if

          call BULKFLUX_diagnose_scales( IA, IS, IE, JA, JS, JE, &
                                         SFLX_MW(:,:), SFLX_MU(:,:), SFLX_MV(:,:),  & ! [IN]
                                         SFLX_SH2(:,:), SFLX_QV(:,:),               & ! [IN]
                                         SFC_DENS(:,:), SFC_POTV(:,:), PBL_Zi(:,:), & ! [IN]
                                         Ustar(:,:), Tstar(:,:), Qstar(:,:),        & ! [OUT]
                                         Wstar(:,:), RLmo(:,:)                      ) ! [OUT]
          !$acc end data

       else

          !$acc data create(ATM_U,ATM_V,ATM_W,ATM_QV)

          !$omp parallel do
          !$acc kernels
          do j = JS, JE
          do i = IS, IE
             ATM_U   (i,j) = U   (KS,i,j)
             ATM_V   (i,j) = V   (KS,i,j)
             ATM_W   (i,j) = ATM_U(i,j) * TanSL_X(i,j) + ATM_V(i,j) * TanSL_Y(i,j)
             ATM_QV  (i,j) = QV  (KS,i,j)
          enddo
          enddo
          !$acc end kernels

          select case ( ATMOS_PHY_SF_TYPE )
          case ( 'BULK' )

             call ATMOS_PHY_SF_bulk_flux( IA, IS, IE, JA, JS, JE,                      & ! [IN]
                                          ATM_W(:,:), ATM_U(:,:), ATM_V(:,:),          & ! [IN]
                                          ATM_TEMP(:,:), ATM_PRES(:,:), ATM_QV(:,:),   & ! [IN]
                                          SFC_DENS(:,:), SFC_TEMP(:,:), SFC_PRES(:,:), & ! [IN]
                                          SFC_Z0M(:,:), SFC_Z0H(:,:), SFC_Z0E(:,:),    & ! [IN]
                                          PBL_Zi(:,:), Z1(:,:),                        & ! [IN]
                                          SFLX_MW(:,:), SFLX_MU(:,:), SFLX_MV(:,:),    & ! [OUT]
                                          SFLX_SH(:,:), SFLX_LH(:,:), SFLX_QV(:,:),    & ! [OUT]
                                          Ustar(:,:), Tstar(:,:), Qstar(:,:),          & ! [OUT]
                                          Wstar(:,:),                                  & ! [OUT]
                                          RLmo(:,:),                                   & ! [OUT]
                                          U10(:,:), V10(:,:), T2(:,:), Q2(:,:)         ) ! [OUT]

          case ( 'CONST' )

             !$acc update host(ATM_W,ATM_U,ATM_V,ATM_TEMP,ATM_PRES,ATM_QV,SFC_DENS)
             call ATMOS_PHY_SF_const_flux( IA, IS, IE, JA, JS, JE,                            & ! [IN]
                                           ATM_W(:,:), ATM_U(:,:), ATM_V(:,:), ATM_TEMP(:,:), & ! [IN]
                                           ATM_PRES(:,:), ATM_QV(:,:), Z1(:,:), SFC_DENS(:,:),& ! [IN]
                                           SFLX_MW(:,:), SFLX_MU(:,:), SFLX_MV(:,:),          & ! [OUT]
                                           SFLX_SH(:,:), SFLX_LH(:,:), SFLX_QV(:,:),          & ! [OUT]
                                           U10(:,:), V10(:,:)                                 ) ! [OUT]
             Ustar(:,:) = UNDEF
             Tstar(:,:) = UNDEF
             Qstar(:,:) = UNDEF
             RLmo (:,:) = UNDEF
             T2(:,:) = ATM_TEMP(:,:)
             Q2(:,:) = ATM_QV(:,:)
             !$acc update device(SFLX_MW,SFLX_MU,SFLX_MV,SFLX_SH,SFLX_LH,SFLX_QV,Ustar,Tstar,Qstar,Wstar,RLmo,U10,V10,T2,Q2)

          end select

          if ( .NOT. ATMOS_HYDROMETEOR_dry ) then
             !$acc kernels
             SFLX_QTRC(:,:,I_QV) = SFLX_QV(:,:)
             SFLX_ENGI(:,:)      = SFLX_QV(:,:) * ( TRACER_CV(I_QV) * SFC_TEMP(:,:) + LHV )
             !$acc end kernels
          endif

          !$acc end data

       endif

       call history_output

!OCL XFILL
       !$omp parallel do &
       !$omp private(rdz)
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          rdz = 1.0_RP / ( FZ(KS,i,j) - FZ(KS-1,i,j) )
          MOMZ_t_SF(i,j) = SFLX_MW(i,j) / ( CZ(KS+1,i,j) - CZ(KS,i,j) )
          RHOU_t_SF(i,j) = SFLX_MU(i,j) * rdz
          RHOV_t_SF(i,j) = SFLX_MV(i,j) * rdz
       enddo
       enddo
       !$acc end kernels

       !$omp parallel do &
       !$omp private(work,rdz,CP_t,CV_t,ENGI_t)
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          rdz = 1.0_RP / ( FZ(KS,i,j) - FZ(KS-1,i,j) )
          DENS_t_SF(i,j) = 0.0_RP
          CP_t = 0.0_RP
          CV_t = 0.0_RP
          ENGI_t = SFLX_ENGI(i,j) * rdz
          !$acc loop seq
          do iq = 1, QA
             work = SFLX_QTRC(i,j,iq) * rdz

             RHOQ_t_SF(i,j,iq) = work
             DENS_t_SF(i,j)    = DENS_t_SF(i,j) + work * TRACER_MASS(iq)
             CP_t              = CP_t + work * TRACER_CP(iq)
             CV_t              = CV_t + work * TRACER_CV(iq)
             ENGI_t            = ENGI_t - TRACER_ENGI0(iq) * work
          end do
          CP_t = ( CP_t - CPtot(KS,i,j) * DENS_t_SF(i,j) ) / ATM_DENS(i,j)
          CV_t = ( CV_t - CVtot(KS,i,j) * DENS_t_SF(i,j) ) / ATM_DENS(i,j)

          RHOH_SF(i,j) = SFLX_SH(i,j) * rdz + ENGI_t &
                       - ( CP_t + log( ATM_PRES(i,j) / PRE00 ) * ( CVtot(KS,i,j) / CPtot(KS,i,j) * CP_t - CV_t ) ) * ATM_DENS(i,j) * ATM_TEMP(i,j)
       enddo
       enddo
       !$acc end kernels

       !$acc end data

    endif

    !$omp parallel do
    !$acc kernels
    do j = JS, JE
    do i = IS, IE
       MOMZ_t(KS,i,j) = MOMZ_t(KS,i,j) + MOMZ_t_SF(i,j)
       RHOU_t(KS,i,j) = RHOU_t(KS,i,j) + RHOU_t_SF(i,j)
       RHOV_t(KS,i,j) = RHOV_t(KS,i,j) + RHOV_t_SF(i,j)
       RHOH  (KS,i,j) = RHOH  (KS,i,j) + RHOH_SF  (i,j)
       DENS_t(KS,i,j) = DENS_t(KS,i,j) + DENS_t_SF(i,j)
    enddo
    enddo
    !$acc end kernels

    !$omp parallel
    !$acc kernels
    do iq = 1, QA
    !$omp do
    do j = JS, JE
    do i = IS, IE
       RHOQ_t(KS,i,j,iq) = RHOQ_t(KS,i,j,iq) + RHOQ_t_SF(i,j,iq)
    enddo
    enddo
    !$omp end do nowait
    enddo
    !$acc end kernels
    !$omp end parallel

    if ( STATISTICS_checktotal ) then

       if ( .NOT. ATMOS_HYDROMETEOR_dry ) then
          do iq = 1, QA
             call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                                    SFLX_QTRC(:,:,iq), 'SFLX_'//trim(TRACER_NAME(iq)), &
                                    ATMOS_GRID_CARTESC_REAL_AREA(:,:),                 &
                                    ATMOS_GRID_CARTESC_REAL_TOTAREA                    )
          enddo
       endif

       call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                              DENS_t_SF(:,:), 'DENS_t_SF',       &
                              ATMOS_GRID_CARTESC_REAL_AREA(:,:), &
                              ATMOS_GRID_CARTESC_REAL_TOTAREA    )
       call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                              MOMZ_t_SF(:,:), 'MOMZ_t_SF',       &
                              ATMOS_GRID_CARTESC_REAL_AREA(:,:), &
                              ATMOS_GRID_CARTESC_REAL_TOTAREA    )
       call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                              RHOU_t_SF(:,:), 'RHOU_t_SF',       &
                              ATMOS_GRID_CARTESC_REAL_AREA(:,:), &
                              ATMOS_GRID_CARTESC_REAL_TOTAREA    )
       call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                              RHOV_t_SF(:,:), 'RHOV_t_SF',       &
                              ATMOS_GRID_CARTESC_REAL_AREA(:,:), &
                              ATMOS_GRID_CARTESC_REAL_TOTAREA    )
       call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                              RHOH_SF  (:,:), 'RHOH_SF',         &
                              ATMOS_GRID_CARTESC_REAL_AREA(:,:), &
                              ATMOS_GRID_CARTESC_REAL_TOTAREA    )

       do iq = 1, QA
          call STATISTICS_total( IA, IS, IE, JA, JS, JE, &
                                 RHOQ_t_SF(:,:,iq), trim(TRACER_NAME(iq))//'_t_SF', &
                                 ATMOS_GRID_CARTESC_REAL_AREA(:,:),                 &
                                 ATMOS_GRID_CARTESC_REAL_TOTAREA                    )
       enddo

    endif

    return
  end subroutine ATMOS_PHY_SF_driver_calc_tendency

  !-----------------------------------------------------------------------------
  subroutine history_output
    use scale_const, only: &
       UNDEF => CONST_UNDEF, &
       Rvap  => CONST_Rvap
    use scale_file_history, only: &
       FILE_HISTORY_query, &
       FILE_HISTORY_in, &
       FILE_HISTORY_put
    use scale_atmos_hydrostatic, only: &
       barometric_law_mslp => ATMOS_HYDROSTATIC_barometric_law_mslp
    use scale_atmos_saturation, only: &
       ATMOS_SATURATION_psat_liq
    use scale_atmos_grid_cartesC_real, only: &
       REAL_CZ => ATMOS_GRID_CARTESC_REAL_CZ
    use scale_atmos_grid_cartesC_metric, only: &
       ROTC => ATMOS_GRID_CARTESC_METRIC_ROTC
    use scale_atmos_hydrometeor, only: &
       ATMOS_HYDROMETEOR_dry, &
       I_QV
    use mod_atmos_vars, only: &
       TEMP, &
       PRES, &
       QV
    use mod_atmos_phy_sf_vars, only: &
       SFC_DENS   => ATMOS_PHY_SF_SFC_DENS,   &
       SFC_PRES   => ATMOS_PHY_SF_SFC_PRES,   &
       SFC_TEMP   => ATMOS_PHY_SF_SFC_TEMP,   &
       SFC_albedo => ATMOS_PHY_SF_SFC_albedo, &
       SFC_Z0M    => ATMOS_PHY_SF_SFC_Z0M,    &
       SFC_Z0H    => ATMOS_PHY_SF_SFC_Z0H,    &
       SFC_Z0E    => ATMOS_PHY_SF_SFC_Z0E,    &
       SFLX_MW    => ATMOS_PHY_SF_SFLX_MW,    &
       SFLX_MU    => ATMOS_PHY_SF_SFLX_MU,    &
       SFLX_MV    => ATMOS_PHY_SF_SFLX_MV,    &
       SFLX_SH    => ATMOS_PHY_SF_SFLX_SH,    &
       SFLX_LH    => ATMOS_PHY_SF_SFLX_LH,    &
       SFLX_GH    => ATMOS_PHY_SF_SFLX_GH,    &
       SFLX_QTRC  => ATMOS_PHY_SF_SFLX_QTRC,  &
       SFLX_ENGI  => ATMOS_PHY_SF_SFLX_ENGI,  &
       Ustar      => ATMOS_PHY_SF_Ustar,      &
       Tstar      => ATMOS_PHY_SF_Tstar,      &
       Qstar      => ATMOS_PHY_SF_Qstar,      &
       Wstar      => ATMOS_PHY_SF_Wstar,      &
       RLmo       => ATMOS_PHY_SF_RLmo,       &
       U10        => ATMOS_PHY_SF_U10,        &
       V10        => ATMOS_PHY_SF_V10,        &
       T2         => ATMOS_PHY_SF_T2,         &
       Q2         => ATMOS_PHY_SF_Q2
    implicit none

    real(RP) :: work(IA,JA)

    logical :: do_put
    integer :: i, j, iq
    !---------------------------------------------------------------------------

    call FILE_HISTORY_in( SFC_DENS  (:,:),                     'SFC_DENS',        'surface atmospheric density',          'kg/m3'   )
    call FILE_HISTORY_in( SFC_PRES  (:,:),                     'SFC_PRES',        'surface atmospheric pressure',         'Pa'      )
    call FILE_HISTORY_in( SFC_TEMP  (:,:),                     'SFC_TEMP',        'surface skin temperature',             'K'       )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_direct ,I_R_IR ), 'SFC_ALB_IR_dir' , 'surface albedo (IR; direct',           '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_diffuse,I_R_IR ), 'SFC_ALB_IR_dif' , 'surface albedo (IR; diffuse)',         '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_direct ,I_R_NIR), 'SFC_ALB_NIR_dir', 'surface albedo (NIR; direct',          '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_diffuse,I_R_NIR), 'SFC_ALB_NIR_dif', 'surface albedo (NIR; diffuse',         '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_direct ,I_R_VIS), 'SFC_ALB_VIS_dir', 'surface albedo (VIS; direct',          '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_albedo(:,:,I_R_diffuse,I_R_VIS), 'SFC_ALB_VIS_dif', 'surface albedo (VIS; diffuse',         '1'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_Z0M   (:,:),                     'SFC_Z0M',         'roughness length (momentum)',           'm'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_Z0H   (:,:),                     'SFC_Z0H',         'roughness length (heat)',               'm'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFC_Z0E   (:,:),                     'SFC_Z0E',         'roughness length (vapor)',              'm'       , fill_halo=.true. )
    call FILE_HISTORY_in( SFLX_MW   (:,:),                     'MWFLX',           'w-momentum flux',                       'kg/m/s2' )
    call FILE_HISTORY_in( SFLX_MU   (:,:),                     'MUFLX',           'u-momentum flux',                       'kg/m/s2' )
    call FILE_HISTORY_in( SFLX_MV   (:,:),                     'MVFLX',           'v-momentum flux',                       'kg/m/s2' )
    call FILE_HISTORY_in( SFLX_SH   (:,:),                     'SHFLX',           'sensible heat flux',                    'W/m2'    , fill_halo=.true. )
    call FILE_HISTORY_in( SFLX_LH   (:,:),                     'LHFLX',           'latent heat flux',                      'W/m2'    , fill_halo=.true. )
    call FILE_HISTORY_in( SFLX_GH   (:,:),                     'GHFLX',           'ground heat flux (downward)',           'W/m2'    , fill_halo=.true. )
    do iq = 1, QA
       call FILE_HISTORY_in( SFLX_QTRC(:,:,iq), 'SFLX_'//trim(TRACER_NAME(iq)), &
                             'surface '//trim(TRACER_NAME(iq))//' flux',        &
                             'kg/m2/s' , fill_halo=.true.                       )
    enddo
    call FILE_HISTORY_in( SFLX_ENGI (:,:),                     'SFLX_ENGI',        'ground internal energy flux (merged)', 'W/m2'    , fill_halo=.true. )

    call FILE_HISTORY_in( Ustar (:,:), 'Ustar',  'friction velocity',         'm/s'  , fill_halo=.true. )
    call FILE_HISTORY_in( Tstar (:,:), 'Tstar',  'temperature scale',         'K'    , fill_halo=.true. )
    call FILE_HISTORY_in( Qstar (:,:), 'Qstar',  'moisuter scale',            'kg/kg', fill_halo=.true. )
    call FILE_HISTORY_in( Wstar (:,:), 'Wstar',  'convective velocity scale', 'm/s',   fill_halo=.true. )
    call FILE_HISTORY_in( RLmo  (:,:), 'RLmo',   'inverse of Obukhov length', '1/m'  , fill_halo=.true. )

    call FILE_HISTORY_in( U10   (:,:), 'U10',    '10m x-wind',                'm/s'  , fill_halo=.true. )
    call FILE_HISTORY_in( V10   (:,:), 'V10',    '10m y-wind',                'm/s'  , fill_halo=.true. )
    call FILE_HISTORY_in( T2    (:,:), 'T2 ',    '2m air temperature',        'K'    , fill_halo=.true. )
    call FILE_HISTORY_in( Q2    (:,:), 'Q2 ',    '2m specific humidity',      'kg/kg', fill_halo=.true. )


    !$acc data create(work)

    call FILE_HISTORY_query( hist_uabs10, do_put )
    if ( do_put ) then
       !$omp parallel do
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          work(i,j) = sqrt( U10(i,j)**2 + V10(i,j)**2 )
       enddo
       enddo
       !$acc end kernels
       call FILE_HISTORY_put( hist_uabs10, work(:,:) )
    end if

    call FILE_HISTORY_query( hist_u10m, do_put )
    if ( do_put ) then
       !$omp parallel do
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          work(i,j) = U10(i,j) * ROTC(i,j,1) - V10(i,j) * ROTC(i,j,2)
       enddo
       enddo
       !$acc end kernels
       call FILE_HISTORY_put( hist_u10m, work(:,:) )
    end if

    call FILE_HISTORY_query( hist_v10m, do_put )
    if ( do_put ) then
       !$omp parallel do
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          work(i,j) = U10(i,j) * ROTC(i,j,2) + V10(i,j) * ROTC(i,j,1)
       enddo
       enddo
       !$acc end kernels
       call FILE_HISTORY_put( hist_v10m, work(:,:) )
    end if

    call FILE_HISTORY_query( hist_rh2, do_put )
    if ( do_put ) then
       call ATMOS_SATURATION_psat_liq( &
            IA, IS, IE, JA, JS, JE, &
            T2(:,:), & ! (in)
            work(:,:)  ) ! (out)
       !$omp parallel do
       !$acc kernels
       do j = JS, JE
       do i = IS, IE
          work(i,j) = SFC_DENS(i,j) * Q2(i,j) &
                     / work(i,j) * Rvap * T2(i,j) &
                     * 100.0_RP
       enddo
       enddo
       !$acc end kernels
       call FILE_HISTORY_put( hist_rh2, work(:,:) )
    end if


    call FILE_HISTORY_query( hist_mslp, do_put )
    if ( do_put ) then
       call barometric_law_mslp( KA, KS, KE, IA, IS, IE, JA, JS, JE,  & ! [IN]
                                 PRES(:,:,:), TEMP(:,:,:), QV(:,:,:), & ! [IN]
                                 REAL_CZ(:,:,:),                      & ! [IN]
                                 work(:,:)                            ) ! [OUT]
       call FILE_HISTORY_put( hist_mslp, work(:,:) )
    end if

    !$acc end data

    return
  end subroutine history_output

end module mod_atmos_phy_sf_driver
