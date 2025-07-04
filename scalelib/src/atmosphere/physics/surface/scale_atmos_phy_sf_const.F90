!-------------------------------------------------------------------------------
!> module atmosphere / physics / surface / const
!!
!! @par Description
!!          Flux from/to bottom wall of atmosphere (surface)
!!          Constant flux, domain-uniform
!!
!! @author Team SCALE
!!
!<
!-------------------------------------------------------------------------------
#include "scalelib.h"
module scale_atmos_phy_sf_const
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_io
  use scale_prof
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: ATMOS_PHY_SF_const_setup
  public :: ATMOS_PHY_SF_const_flux

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
  integer,  private            :: ATMOS_PHY_SF_FLG_MOM_FLUX = 0 ! application type for momentum flux
                                                                ! 0: Bulk coefficient  is constant
                                                                ! 1: Friction velocity is constant

  real(RP), private, parameter :: ATMOS_PHY_SF_U_maxM      =  100.0_RP ! maximum limit of absolute velocity for momentum [m/s]
  real(RP), private            :: ATMOS_PHY_SF_U_minM      =    0.0_RP ! minimum limit of absolute velocity for momentum [m/s]
  real(RP), private, parameter :: ATMOS_PHY_SF_Cm_max      = 2.5E-3_RP ! maximum limit of bulk coefficient for momentum [NIL]
  real(RP), private            :: ATMOS_PHY_SF_Cm_min      = 1.0E-5_RP ! minimum limit of bulk coefficient for momentum [NIL]

  real(RP), private            :: ATMOS_PHY_SF_Const_Ustar =   0.25_RP ! constant friction velocity [m/s]
  real(RP), private            :: ATMOS_PHY_SF_Const_Cm    = 0.0011_RP ! constant bulk coefficient for momentum [NIL]
  real(RP), private            :: ATMOS_PHY_SF_Const_SH    =   15.0_RP ! constant surface sensible heat flux [W/m2]
  real(RP), private            :: ATMOS_PHY_SF_Const_LH    =  115.0_RP ! constant surface latent   heat flux [W/m2]

  logical,  private            :: ATMOS_PHY_SF_FLG_SH_DIURNAL = .false. ! diurnal modulation for sensible heat flux?
  real(RP), private            :: ATMOS_PHY_SF_Const_FREQ     = 24.0_RP ! frequency of sensible heat flux modulation [hour]

  logical,  private            :: ATMOS_PHY_SF_FLG_CG96 = .false.  ! Use another scheme?
  real(RP), private            :: ATMOS_PHY_SF_COEF_MOM    = 1.0_RP
  real(RP), private            :: ATMOS_PHY_SF_COEF_SH     = 1.0_RP
  real(RP), private            :: ATMOS_PHY_SF_COEF_QV     = 1.0_RP
  real(RP), private            :: ATMOS_PHY_SF_SFC_TEMP    = 301.0_RP
  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine ATMOS_PHY_SF_const_setup
    use scale_prc, only: &
       PRC_abort
    implicit none

    namelist / PARAM_ATMOS_PHY_SF_CONST / &
       ATMOS_PHY_SF_FLG_MOM_FLUX,   &
       ATMOS_PHY_SF_U_minM,         &
       ATMOS_PHY_SF_CM_min,         &
       ATMOS_PHY_SF_Const_Ustar,    &
       ATMOS_PHY_SF_Const_Cm,       &
       ATMOS_PHY_SF_Const_SH,       &
       ATMOS_PHY_SF_Const_LH,       &
       ATMOS_PHY_SF_FLG_SH_DIURNAL, &
       ATMOS_PHY_SF_Const_FREQ,     &
       ATMOS_PHY_SF_FLG_CG96,       &
       ATMOS_PHY_SF_COEF_MOM,       &
       ATMOS_PHY_SF_COEF_SH,        &
       ATMOS_PHY_SF_COEF_QV,        &
       ATMOS_PHY_SF_SFC_TEMP


    integer :: ierr
    !---------------------------------------------------------------------------

    LOG_NEWLINE
    LOG_INFO("ATMOS_PHY_SF_const_setup",*) 'Setup'
    LOG_INFO("ATMOS_PHY_SF_const_setup",*) 'Constant flux'

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_ATMOS_PHY_SF_CONST,iostat=ierr)
    if( ierr < 0 ) then !--- missing
       LOG_INFO("ATMOS_PHY_SF_const_setup",*) 'Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       LOG_ERROR("ATMOS_PHY_SF_const_setup",*) 'Not appropriate names in namelist PARAM_ATMOS_PHY_SF_CONST. Check!'
       call PRC_abort
    endif
    LOG_NML(PARAM_ATMOS_PHY_SF_CONST)

    return
  end subroutine ATMOS_PHY_SF_const_setup

  !-----------------------------------------------------------------------------
  !> Constant flux
  subroutine ATMOS_PHY_SF_const_flux( &
       IA, IS, IE, JA, JS, JE, &
       ATM_W, ATM_U, ATM_V, ATM_TEMP, ATM_PRES,     &
       ATM_QV, ATM_Z1, SFC_DENS,                    &
       SFLX_MW, SFLX_MU, SFLX_MV, SFLX_SH, SFLX_LH, &
       SFLX_QV,                                     &
       U10, V10                                     )
    use scale_const, only: &
       PI      => CONST_PI,      &
       Rdry    => CONST_Rdry,    &
       CPdry   => CONST_CPdry,   &
       PRE00   => CONST_PRE00
    use scale_atmos_hydrometeor, only: &
       HYDROMETEOR_LHV => ATMOS_HYDROMETEOR_LHV
    use scale_atmos_saturation, only: &
       SATURATION_pres2qsat_all => ATMOS_SATURATION_pres2qsat_all 
    use scale_time, only: &
       TIME_NOWSEC
    implicit none
    integer, intent(in) :: IA, IS, IE
    integer, intent(in) :: JA, JS, JE

    real(RP), intent(in) :: ATM_W   (IA,JA) ! velocity w  at the lowermost layer (cell center) [m/s]
    real(RP), intent(in) :: ATM_U   (IA,JA) ! velocity u  at the lowermost layer (cell center) [m/s]
    real(RP), intent(in) :: ATM_V   (IA,JA) ! velocity v  at the lowermost layer (cell center) [m/s]
    real(RP), intent(in) :: ATM_TEMP(IA,JA) ! temperature at the lowermost layer (cell center) [K]
    real(RP), intent(in) :: ATM_PRES(IA,JA) ! pressure    at the lowermost layer (cell center) [Pa]
    real(RP), intent(in) :: ATM_QV  (IA,JA) ! qv          at the lowermost layer (cell center) [kg/kg]
    real(RP), intent(in) :: ATM_Z1  (IA,JA) ! height of the lowermost grid from surface (cell center) [m]
    real(RP), intent(in) :: SFC_DENS(IA,JA) ! density     at the surface atmosphere [kg/m3]

    real(RP), intent(out) :: SFLX_MW(IA,JA) ! surface flux for z-momentum    (area center)   [m/s*kg/m2/s]
    real(RP), intent(out) :: SFLX_MU(IA,JA) ! surface flux for x-momentum    (area center)   [m/s*kg/m2/s]
    real(RP), intent(out) :: SFLX_MV(IA,JA) ! surface flux for y-momentum    (area center)   [m/s*kg/m2/s]
    real(RP), intent(out) :: SFLX_SH(IA,JA) ! surface flux for sensible heat (area center)   [J/m2/s]
    real(RP), intent(out) :: SFLX_LH(IA,JA) ! surface flux for latent   heat (area center)   [J/m2/s]
    real(RP), intent(out) :: SFLX_QV(IA,JA) ! surface flux for qv            (area center)   [kg/m2/s]
    real(RP), intent(out) :: U10    (IA,JA) ! velocity u        at 10m height
    real(RP), intent(out) :: V10    (IA,JA) ! velocity v        at 10m height

    real(RP) :: ATM_Uabs(IA,JA) ! absolute velocity at z1 [m/s]

    real(RP) :: Cm(IA,JA)       ! bulk coefficient for momentum
    real(RP) :: R10

    real(RP) :: modulation
    real(RP) :: LHV(IA,JA)

    real(RP) :: cm_deacon
    real(RP) :: pt_atm
    real(RP) :: pt_sfc
    real(RP) :: qv_sfc
   
    integer  :: i, j
    !---------------------------------------------------------------------------

    LOG_PROGRESS(*) 'atmosphere / physics / surface flux / const'

    !$omp parallel do
    do j = JS, JE
    do i = IS, IE
      ATM_Uabs(i,j) = min( ATMOS_PHY_SF_U_maxM, max( ATMOS_PHY_SF_U_minM, &
         sqrt( ATM_W(i,j)**2 + ATM_U(i,j)**2 + ATM_V(i,j)**2 ) ) ) ! at cell center
    enddo
    enddo

    if (ATMOS_PHY_SF_FLG_CG96 == .false.) then  ! Use default scheme

      if   ( ATMOS_PHY_SF_FLG_MOM_FLUX == 0 ) then ! Bulk coefficient is constant
         !$omp parallel do
         do j = JS, JE
         do i = IS, IE
            Cm(i,j) = ATMOS_PHY_SF_Const_Cm
         enddo
         enddo
      elseif( ATMOS_PHY_SF_FLG_MOM_FLUX == .true. ) then ! Friction velocity is constant
         !$omp parallel do
         do j = JS, JE
         do i = IS, IE
            Cm(i,j) = ( ATMOS_PHY_SF_Const_Ustar / ATM_Uabs(i,j) )**2
            Cm(i,j) = min( max( Cm(i,j), ATMOS_PHY_SF_Cm_min ), ATMOS_PHY_SF_Cm_max )
         enddo
         enddo
      endif

      !-----< momentum >-----

      !$omp parallel do
      do j = JS, JE
      do i = IS, IE
         SFLX_MW(i,j) = -Cm(i,j) * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_W(i,j)
         SFLX_MU(i,j) = -Cm(i,j) * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_U(i,j)
         SFLX_MV(i,j) = -Cm(i,j) * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_V(i,j)
      enddo
      enddo

      !-----< heat flux >-----

      if ( ATMOS_PHY_SF_FLG_SH_DIURNAL ) then
         modulation = sin( 2.0_RP * PI * TIME_NOWSEC / 3600.0_RP / ATMOS_PHY_SF_Const_FREQ )
      else
         modulation = 1.0_RP
      endif

      !$omp parallel do
      do j = JS, JE
      do i = IS, IE
         SFLX_SH(i,j) = ATMOS_PHY_SF_Const_SH * modulation
         SFLX_LH(i,j) = ATMOS_PHY_SF_Const_LH
      enddo
      enddo

      !-----< mass flux >-----
      call HYDROMETEOR_LHV( &
            IA, IS, IE, JA, JS, JE, &
            ATM_TEMP(:,:), & ! [IN]
            LHV(:,:)       ) ! [OUT]

      !$omp parallel do
      do j = JS, JE
      do i = IS, IE
         SFLX_QV(i,j) = SFLX_LH(i,j) / LHV(i,j)
      enddo
      enddo

    elseif (ATMOS_PHY_SF_FLG_CG96 == .true.) then  ! Use CG96 scheme
      !-----< momentum >-----
      
      !$omp parallel do &
      !$omp private(cm_deacon)
      do j = JS, JE
      do i = IS, IE
         cm_deacon = 0.0011_RP + 0.00004_RP * ATM_Uabs(i,j)  ! Deacon's formula
         SFLX_MW(i,j) = -ATMOS_PHY_SF_COEF_MOM * cm_deacon * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_W(i,j)
         SFLX_MU(i,j) = -ATMOS_PHY_SF_COEF_MOM * cm_deacon * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_U(i,j)
         SFLX_MV(i,j) = -ATMOS_PHY_SF_COEF_MOM * cm_deacon * ATM_Uabs(i,j) * SFC_DENS(i,j) * ATM_V(i,j)
      enddo
      enddo

      !-----< heat flux >-----

      call HYDROMETEOR_LHV( &
         IA, IS, IE, JA, JS, JE, &
         ATM_TEMP(:,:), & ! [IN]
         LHV(:,:)       ) ! [OUT]

      !$omp parallel do &
      !$omp private(pt_atm,pt_sfc,qv_sfc)
      do j = JS, JE
      do i = IS, IE
         pt_atm = ATM_TEMP(i,j) * ( PRE00 / ATM_PRES(i,j) )**( Rdry / CPdry )
         pt_sfc = ATMOS_PHY_SF_SFC_TEMP * ( PRE00 / ATM_PRES(i,j) )**( Rdry / CPdry )
         call SATURATION_pres2qsat_all( &
         ATMOS_PHY_SF_SFC_TEMP, ATM_PRES(i,j) , &  ! [IN]
         qv_sfc   )                                ! [OUT]
         SFLX_SH(i,j) = ATMOS_PHY_SF_COEF_SH * 0.0010_RP * ATM_Uabs(i,j) * (pt_sfc - pt_atm)
         SFLX_QV(i,j) = ATMOS_PHY_SF_COEF_QV * 0.0012_RP * ATM_Uabs(i,j) * (qv_sfc - ATM_QV(i,j))
         SFLX_LH(i,j) = SFLX_QV(i,j) * LHV(i,j)
      enddo
      enddo

    endif

    !-----< U10, V10 >-----

    !$omp parallel do &
    !$omp private(R10)
    do j = JS, JE
    do i = IS, IE
       R10 = 10.0_RP / ATM_Z1(i,j)

       U10   (i,j) = R10 * ATM_U(i,j)
       V10   (i,j) = R10 * ATM_V(i,j)
    enddo
    enddo

    return
  end subroutine ATMOS_PHY_SF_const_flux

end module scale_atmos_phy_sf_const
