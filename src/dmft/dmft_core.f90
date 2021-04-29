!!!-----------------------------------------------------------------------
!!! project : jacaranda
!!! program : dmft_driver
!!!           map_chi_psi
!!!           map_psi_chi
!!! source  : dmft_core.f90
!!! type    : subroutines
!!! author  : li huang (email:lihuang.dmft@gmail.com)
!!! history : 02/23/2021 by li huang (created)
!!!           04/28/2021 by li huang (last modified)
!!! purpose :
!!! status  : unstable
!!! comment :
!!!-----------------------------------------------------------------------

!!
!! @sub dmft_driver
!!
  subroutine dmft_driver()
     implicit none

     call cal_grn_l(1)

     return
  end subroutine dmft_driver

!!
!! @sub cal_grn_l
!!
!! try to calculate local green's function for given impurity site
!!
  subroutine cal_grn_l(t)
     use constants, only : dp
     use constants, only : czero, czi

     use control, only : nkpt, nspin
     use control, only : nmesh
     use control, only : fermi

     use context, only : i_grp
     use context, only : ndim
     use context, only : kwin
     use context, only : enk
     use context, only : fmesh
     use context, only : sig_l, sigdc
     use context, only : grn_l

     implicit none

! external arguments
! index for impurity sites
     integer, intent(in) :: t

! local variables
! loop index for spin
     integer :: s

! loop index for k-points
     integer :: k

! loop index for frequency mesh
     integer :: m

! status flag
     integer :: istat

! number of correlated orbitals for given impurity site
     integer :: cdim

! number of dft bands for given k-point and spin
     integer :: cbnd

! band window: start index and end index for bands
     integer :: bs, be

! dummy array: for band dispersion (vector)
     complex(dp), allocatable :: Hm(:)

! dummy array: for band dispersion (diagonal matrix)
     complex(dp), allocatable :: Tm(:,:)

! dummy array: for self-energy function (projected to Kohn-Sham basis)
     complex(dp), allocatable :: Sm(:,:)

! dummy array: for local green's function 
     complex(dp), allocatable :: Gm(:,:)

! init cbnd and cdim
! cbnd will be k-dependent. it will be updated later
     cbnd = 0
     cdim = ndim(t)

! reset grn_l
     grn_l(:,:,:,:,t) = czero

! reset sigdc, only for debug
     sigdc = czero

! allocate memory for Gm
     allocate(Gm(cdim,cdim), stat = istat)
     if ( istat /= 0 ) then
         call s_print_error('cal_grn_l','can not allocate enough memory')
     endif ! back if ( istat /= 0 ) block

     SPIN_LOOP: do s=1,nspin
         KPNT_LOOP: do k=1,nkpt
             bs = kwin(k,s,1,i_grp(t))
             be = kwin(k,s,2,i_grp(t))
             cbnd = be - bs + 1
             print *, s, k, t, cbnd, cdim

             allocate(Hm(cbnd))
             allocate(Tm(cbnd,cbnd))
             allocate(Sm(cbnd,cbnd))

             FREQ_LOOP: do m=1,nmesh

                 Hm = czi * fmesh(m) + fermi - enk(bs:be,k,s)
                 call s_diag_z(cbnd, Hm, Tm)

! add self-energy function here
                 Gm = sig_l(1:cdim,1:cdim,m,s,t) - sigdc(1:cdim,1:cdim,s,t)
                 if ( m == 1 ) then
                     Gm(1,1) = dcmplx(1.200, 5.0)
                     Gm(2,2) = dcmplx(1.000, -0.14) 
                     Gm(3,3) = dcmplx(2.200, 3.0)
                     Gm(4,4) = dcmplx(0.800, -0.1)
                     Gm(5,5) = dcmplx(1.255, 2.0_dp)

                     Gm(2,4) = dcmplx(-1.0, 0.34)
                     Gm(1,4) = dcmplx(-1.0, 0.34)
                     Gm(3,1) = dcmplx(-1.0, 0.34)
                     Gm(1,5) = dcmplx(-1.0, 0.34)
                 endif

                 call map_chi_psi(cdim, cbnd, k, s, t, Gm, Sm)

                 Tm = Tm - Sm

                 call s_inv_z(cbnd, Tm)

                 call map_psi_chi(cbnd, cdim, k, s, t, Tm, Gm)

                 grn_l(1:cdim,1:cdim,m,s,t) = grn_l(1:cdim,1:cdim,m,s,t) + Gm
             enddo FREQ_LOOP ! over m={1,nmesh} loop

             deallocate(Hm)
             deallocate(Tm)
             deallocate(Sm)
         enddo KPNT_LOOP ! over k={1,nkpt} loop
     enddo SPIN_LOOP ! over s={1,nspin} loop

     grn_l = grn_l / float(nkpt)
     do s=1,ndim(t)
         print *, s,grn_l(s,s, 1, 1, t)
     enddo

     deallocate(Gm)

     return
  end subroutine cal_grn_l

  subroutine cal_hyb_l()
     implicit none

     return
  end subroutine cal_hyb_l

  subroutine cal_wss_l()
     implicit none

     return
  end subroutine cal_wss_l

!!
!! @sub map_chi_psi
!!
  subroutine map_chi_psi(cdim, cbnd, k, s, t, Mc, Mp)
     use constants, only : dp

     use context, only : i_grp
     use context, only : psichi
     use context, only : chipsi

     implicit none

! external arguments
     integer, intent(in) :: cdim
     integer, intent(in) :: cbnd
     integer, intent(in) :: k
     integer, intent(in) :: s
     integer, intent(in) :: t

     complex(dp), intent(in)  :: Mc(cdim,cdim)
     complex(dp), intent(out) :: Mp(cbnd,cbnd)

     Mp = matmul( matmul(chipsi(1:cbnd,1:cdim,k,s,i_grp(t)), Mc), &
                         psichi(1:cdim,1:cbnd,k,s,i_grp(t)) )

     return
  end subroutine map_chi_psi

!!
!! @sub map_psi_chi
!!
  subroutine map_psi_chi(cbnd, cdim, k, s, t, Mp, Mc)
     use constants, only : dp

     use context, only : i_grp
     use context, only : psichi
     use context, only : chipsi

     implicit none

! external arguments
     integer, intent(in) :: cbnd
     integer, intent(in) :: cdim
     integer, intent(in) :: k
     integer, intent(in) :: s
     integer, intent(in) :: t

     complex(dp), intent(in)  :: Mp(cbnd,cbnd)
     complex(dp), intent(out) :: Mc(cdim,cdim)

     Mc = matmul( matmul(psichi(1:cdim,1:cbnd,k,s,i_grp(t)), Mp), &
                         chipsi(1:cbnd,1:cdim,k,s,i_grp(t)) )

     return
  end subroutine map_psi_chi
