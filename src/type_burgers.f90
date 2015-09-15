!< Define Burgers field that is a concrete extension of the abstract integrand type.
module type_burgers
!-----------------------------------------------------------------------------------------------------------------------------------
!< Define Burgers field that is a concrete extension of the abstract integrand type.
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
use IR_Precision, only : R_P, I_P
use foodie, only : integrand
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
implicit none
private
public :: burgers
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
type, extends(integrand) :: burgers
  !< Burgers equations field.
  !<
  !< It is a FOODiE integrand class.
  private
  integer(I_P)                           :: Ni=0      !< Number of grid nodes.
  integer(I_P)                           :: steps=0   !< Number of time steps stored.
  real(R_P)                              :: h=0._R_P  !< Space step discretization.
  real(R_P)                              :: nu=0._R_P !< Viscosity.
  real(R_P), dimension(:),   allocatable :: state     !< Solution vector, whole physical domain, [1:Ni].
  real(R_P), dimension(:,:), allocatable :: previous  !< Previous steps solution vector, [1:Ni,1:steps].
  contains
    ! public methods
    ! auxiliary methods
    procedure, pass(self), public :: init             !< Init field.
    procedure, pass(self), public :: output           !< Extract Burgers field.
    procedure, pass(self), public :: dt => compute_dt !< Compute the current time step, by means of CFL condition.
    ! type_integrand deferred methods
    procedure, pass(self), public :: t => dBurgers_dt                                         !< Time derivate, residuals function.
    procedure, pass(self), public :: update_previous_steps                                    !< Update previous time steps.
    procedure, pass(lhs),  public :: integrand_multiply_integrand => burgers_multiply_burgers !< Burgers * burgers operator.
    procedure, pass(lhs),  public :: integrand_multiply_real => burgers_multiply_real         !< Burgers * real operator.
    procedure, pass(rhs),  public :: real_multiply_integrand => real_multiply_burgers         !< Real * Burgers operator.
    procedure, pass(lhs),  public :: add => add_burgers                                       !< Burgers + Burgers oprator.
    procedure, pass(lhs),  public :: sub => sub_burgers                                       !< Burgers - Burgers oprator.
    procedure, pass(lhs),  public :: assign_integrand => burgers_assign_burgers               !< Burgers = Burgers.
    procedure, pass(lhs),  public :: assign_real => burgers_assign_real                       !< Burgers = real.
    ! operators overloading
    generic, public :: operator(-) => sub
    ! private methods
    procedure, pass(self), private :: x  => dBurgers_dx   !< 1st derivative.
    procedure, pass(self), private :: xx => d2Burgers_dx2 !< 2nd derivative.
endtype burgers
!-----------------------------------------------------------------------------------------------------------------------------------
contains
  ! public methods
  subroutine init(self, initial_state, Ni, h, nu, steps)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Construct an initialized Burgers field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),             intent(INOUT) :: self          !< Burgers field.
  integer(I_P),               intent(IN)    :: Ni            !< Number of grid nodes.
  real(R_P), dimension(1:Ni), intent(IN)    :: initial_state !< Initial state of Burgers field domain.
  real(R_P),                  intent(IN)    :: h             !< Space step discretization.
  real(R_P),                  intent(IN)    :: nu            !< Viscosity.
  integer(I_P), optional,     intent(IN)    :: steps         !< Time steps stored.
  integer(I_P)                              :: s             !< Time steps counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  self%steps = 0 ; if (present(steps)) self%steps = steps
  if (allocated(self%state)) deallocate(self%state) ; allocate(self%state(1:Ni))
  if (self%steps>0) then
    if (allocated(self%previous)) deallocate(self%previous) ; allocate(self%previous(1:Ni, 1:self%steps))
  endif
  self%state = initial_state
  if (self%steps>0) then
    do s=1, self%steps
      self%previous(:, s) = initial_state
    enddo
  endif
  self%Ni = Ni
  self%h = h
  self%nu = nu
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine init

  function output(self) result(state)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Output the Burgers field state.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers), intent(IN)           :: self  !< Burgers field.
  real(R_P), dimension(:), allocatable :: state !< Burgers state variable.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  state = self%state
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction output

  pure function compute_dt(self, CFL) result(dt)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the current time step, by means of CFL condition.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers), intent(IN) :: self !< Burgers field.
  real(R_P),      intent(IN) :: CFL  !< Courant-Friedricks-Lewi stability coefficient.
  real(R_P)                  :: dt   !< Current time step.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  dt = CFL * self%h**2 / self%nu
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction compute_dt

  pure function dBurgers_dt(self, n) result(dState_dt)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Time derivative of Burgers field, residuals function.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),         intent(IN) :: self      !< Burgers field.
  integer(I_P), optional, intent(IN) :: n         !< Time level.
  class(integrand), allocatable      :: dState_dt !< Burgers field time derivative.
  type(burgers),    allocatable      :: delta     !< Delta state used as temporary variables.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  ! preparing temporary variables
  allocate(burgers :: delta)
  delta%Ni = self%Ni
  delta%steps = self%steps
  delta%h = self%h
  delta%nu = self%nu
  delta%state = self%state
  if (allocated(self%previous)) delta%previous = self%previous
  ! Burgers residuals
  delta = self%xx(n=n) * self%nu
  delta = delta - self * self%x(n=n)
  call move_alloc(delta, dState_dt)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction dBurgers_dt

  pure subroutine update_previous_steps(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Update previous time steps.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers), intent(INOUT) :: self !< Burgers field.
  integer(I_P)                  :: s    !< Time steps counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  if (self%steps>0) then
    do s=1, self%steps - 1
      self%previous(:, s) = self%previous(:, s + 1)
    enddo
    self%previous(:, self%steps) = self%state
  endif
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine update_previous_steps

  ! operators overloading
  pure function burgers_multiply_burgers(lhs, rhs) result(product)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Multiply a Burgers field by another one.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),   intent(IN)  :: lhs           !< Left hand side.
  class(integrand), intent(IN)  :: rhs           !< Right hand side.
  class(integrand), allocatable :: product       !< Product.
  type(burgers),    allocatable :: local_product !< Temporary produtc.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(local_product)
  select type(rhs)
  class is (burgers)
    local_product%Ni = lhs%Ni
    local_product%steps = lhs%steps
    local_product%h = lhs%h
    local_product%nu = lhs%nu
    local_product%state = lhs%state * rhs%state
    if (allocated(lhs%previous)) local_product%previous = lhs%previous
  endselect
  call move_alloc(local_product, product)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction burgers_multiply_burgers

  pure function burgers_multiply_real(lhs, rhs) result(product)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Multiply a Burgers field by a real scalar.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers), intent(IN)    :: lhs           !< Left hand side.
  real(R_P),      intent(IN)    :: rhs           !< Right hand side.
  class(integrand), allocatable :: product       !< Product.
  type(burgers),    allocatable :: local_product !< Temporary produtc.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(local_product)
  local_product%Ni = lhs%Ni
  local_product%steps = lhs%steps
  local_product%h = lhs%h
  local_product%nu = lhs%nu
  local_product%state = lhs%state * rhs
  if (allocated(lhs%previous)) local_product%previous = lhs%previous
  call move_alloc(local_product, product)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction burgers_multiply_real

  pure function real_multiply_burgers(lhs, rhs) result(product)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Multiply a real scalar by a Burgers field.
  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P),      intent(IN)    :: lhs           !< Left hand side.
  class(burgers), intent(IN)    :: rhs           !< Right hand side.
  class(integrand), allocatable :: product       !< Product.
  type(burgers),    allocatable :: local_product !< Temporary produtc.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(local_product)
  local_product%Ni = rhs%Ni
  local_product%steps = rhs%steps
  local_product%h = rhs%h
  local_product%nu = rhs%nu
  local_product%state = rhs%state * lhs
  if (allocated(rhs%previous)) local_product%previous = rhs%previous
  call move_alloc(local_product, product)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction real_multiply_burgers

  pure function add_burgers(lhs, rhs) result(sum)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Add two Burgers fields.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),   intent(IN)  :: lhs       !< Left hand side.
  class(integrand), intent(IN)  :: rhs       !< Right hand side.
  class(integrand), allocatable :: sum       !< Sum.
  type(burgers),    allocatable :: local_sum !< Temporary sum.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(local_sum)
  select type(rhs)
  class is (burgers)
    local_sum%Ni = lhs%Ni
    local_sum%steps = lhs%steps
    local_sum%h = lhs%h
    local_sum%nu = lhs%nu
    local_sum%state = lhs%state + rhs%state
    if (allocated(lhs%previous)) local_sum%previous = lhs%previous
  endselect
  call move_alloc(local_sum, sum)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction add_burgers

  pure function sub_burgers(lhs, rhs) result(sub)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Subtract two Burgers fields.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),   intent(IN)  :: lhs       !< Left hand side.
  class(integrand), intent(IN)  :: rhs       !< Right hand side.
  class(integrand), allocatable :: sub       !< Subtraction.
  type(burgers),    allocatable :: local_sub !< Temporary subtraction.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(local_sub)
  select type(rhs)
  class is (burgers)
    local_sub%Ni = lhs%Ni
    local_sub%steps = lhs%steps
    local_sub%h = lhs%h
    local_sub%nu = lhs%nu
    local_sub%state = lhs%state - rhs%state
    if (allocated(lhs%previous)) local_sub%previous = lhs%previous
  endselect
  call move_alloc(local_sub, sub)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction sub_burgers

  pure subroutine burgers_assign_burgers(lhs, rhs)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Assign one Burgers field to another.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),   intent(INOUT) :: lhs !< Left hand side.
  class(integrand), intent(IN)    :: rhs !< Right hand side.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  select type(rhs)
  class is (burgers)
    lhs%Ni = rhs%Ni
    lhs%steps = rhs%steps
    lhs%h = rhs%h
    lhs%nu = rhs%nu
    if (allocated(rhs%state)) lhs%state = rhs%state
    if (allocated(rhs%previous)) lhs%previous = rhs%previous
  endselect
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine burgers_assign_burgers

  pure subroutine burgers_assign_real(lhs, rhs)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Assign one real to a Burgers field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers), intent(INOUT) :: lhs !< Left hand side.
  real(R_P),      intent(IN)    :: rhs !< Right hand side.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  if (allocated(lhs%state)) lhs%state = rhs
  if (allocated(lhs%previous)) lhs%previous = rhs
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine burgers_assign_real

  ! private methods
  pure function dBurgers_dx(self, n) result(derivative)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the first order spatial derivative of Burgers field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),    intent(IN) :: self       !< Burgers field.
  integer, optional, intent(IN) :: n          !< Time level.
  type(burgers), allocatable    :: derivative !< Burgers field derivative.
  integer(I_P)                  :: i          !< Counter.
  integer                       :: dn         !< Time level, dummy variable.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(derivative)
  derivative%Ni = self%Ni
  derivative%steps = self%steps
  derivative%h = self%h
  derivative%nu = self%nu
  derivative%state = self%state
  if (allocated(self%previous)) derivative%previous = self%previous
  if (self%steps>=2) then ! self%previous should be used
    dn = self%steps ; if (present(n)) dn = n
    do i=2, self%Ni - 1
      derivative%state(i) = (self%previous(i+1, dn) - self%previous(i-1, dn))/(2._R_P * self%h)
    enddo
    derivative%state(1) = (self%previous(2, dn) - self%previous(self%Ni, dn))/(2._R_P * self%h)
    derivative%state(self%Ni) = (self%previous(1, dn) - self%previous(self%Ni-1, dn))/(2._R_P * self%h)
  else ! self%previous should not be used, use directly self%state
    do i=2, self%Ni - 1
      derivative%state(i) = (self%state(i+1) - self%state(i-1))/(2._R_P * self%h)
    enddo
    derivative%state(1) = (self%state(2) - self%state(self%Ni))/(2._R_P * self%h)
    derivative%state(self%Ni) = (self%state(1) - self%state(self%Ni-1))/(2._R_P * self%h)
  endif
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction

  pure function d2Burgers_dx2(self, n) result(derivative)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the second order spatial derivative of Burgers field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(burgers),    intent(IN) :: self       !< Burgers field.
  integer, optional, intent(IN) :: n          !< Time level.
  type(burgers), allocatable    :: derivative !< Burgers field derivative.
  integer(I_P)                  :: i          !< Counter.
  integer                       :: dn         !< Time level, dummy variable.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(derivative)
  derivative%Ni = self%Ni
  derivative%steps = self%steps
  derivative%h = self%h
  derivative%nu = self%nu
  derivative%state = self%state
  if (allocated(self%previous)) derivative%previous = self%previous
  if (self%steps>=2) then ! self%previous should be used
    dn = self%steps ; if (present(n)) dn = n
    do i=2, self%Ni - 1
      derivative%state(i) = (self%previous(i+1, dn) - 2._R_P * self%previous(i, dn) + self%previous(i-1, dn))/(self%h**2)
    enddo
    derivative%state(1) = (self%previous(2, dn) - 2._R_P * self%previous(1, dn) + self%previous(self%Ni, dn))/(self%h**2)
    derivative%state(self%Ni) = (self%previous(1, dn) - 2._R_P * self%previous(self%Ni, dn) + self%previous(self%Ni-1, dn))/&
                                (self%h**2)
  else ! self%previous should not be used, use directly self%state
    do i=2, self%Ni - 1
      derivative%state(i) = (self%state(i+1) - 2._R_P * self%state(i) + self%state(i-1))/(self%h**2)
    enddo
    derivative%state(1) = (self%state(2) - 2._R_P * self%state(1) + self%state(self%Ni))/(self%h**2)
    derivative%state(self%Ni) = (self%state(1) - 2._R_P * self%state(self%Ni) + self%state(self%Ni-1))/(self%h**2)
  endif
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction
endmodule type_burgers