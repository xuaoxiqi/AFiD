!=======================================================================
! This is part of the 2DECOMP&FFT library
! 
! 2DECOMP&FFT is a software framework for general-purpose 2D (pencil) 
! decomposition. It also implements a highly scalable distributed
! three-dimensional Fast Fourier Transform (FFT).
!
! Copyright (C) 2009-2012 Ning Li, the Numerical Algorithms Group (NAG)
!
!=======================================================================

    s1 = size(in,1)
    s2 = size(in,2)
    s3 = size(in,3)

    ! Calculate the starting index and ending index of output
    xs = 1
    xe = s1
    ys = 1 + level
    ye = s2 - level
    zs = 1 + level
    ze = s3  - level

    s2 = s2 - 2
    s3 = s3 - 2
    ! If needed, define MPI derived data type to pack halo data,
    ! then call MPI send/receive to exchange halo data

       ! *** north/south *** 
 
     tag_s = coord(1)
      if (coord(1)==dims(1)-1 .AND. periodic_y) then
         tag_n = 0
      else
         tag_n = coord(1) + 1
      end if
       icount = s3
       ilength = level * s1
       ijump = s1*(s2+2*level)

     if(tag_n.ne.tag_s) then
       call MPI_TYPE_VECTOR(icount, ilength, ijump, &
            data_type, halo12, ierror)
       call MPI_TYPE_COMMIT(halo12, ierror)
       ! receive from south
       call MPI_IRECV(in(xs,ys-level,zs), 1, halo12, &
            neighbour(1,4), tag_s, DECOMP_2D_COMM_CART_X, &
            requests(1), ierror)
       ! receive from north
       call MPI_IRECV(in(xs,ye+level,zs), 1, halo12, &
            neighbour(1,3), tag_n, DECOMP_2D_COMM_CART_X, &
            requests(2), ierror)
       ! send to south
       call MPI_ISSEND(in(xs,ys,zs), 1, halo12, &
            neighbour(1,4), tag_s, DECOMP_2D_COMM_CART_X, &
            requests(3), ierror)
       ! send to north
       call MPI_ISSEND(in(xs,ye,zs), 1, halo12, &
            neighbour(1,3), tag_n, DECOMP_2D_COMM_CART_X, &
            requests(4), ierror)
       call MPI_WAITALL(4, requests, status, ierror)
       call MPI_TYPE_FREE(halo12, ierror)
      else
!EP   MEMCPY when already in local memory to avoid indirect indexing
!EP   Performance difference unchecked
      in(:,ye+1,:) = in(:,ys,:)
      in(:,ys-1,:) = in(:,ye,:)
     endif

       ! *** top/bottom ***
      tag_b = coord(2)
       if (coord(2)==dims(2)-1 .AND. periodic_z) then
          tag_t = 0
       else
         tag_t = coord(2) + 1
       end if

      ys = 1 
      s2 = s2 +2

       icount = (s1 * s2) * level

     if(tag_t.ne.tag_b) then
       ! receive from bottom
       call MPI_IRECV(in(xs,ys,zs-level), icount, data_type, &
            neighbour(1,6), tag_b, DECOMP_2D_COMM_CART_X, &
            requests(1), ierror)
       ! receive from top
       call MPI_IRECV(in(xs,ys,ze+level), icount, data_type, &
            neighbour(1,5), tag_t, DECOMP_2D_COMM_CART_X, &
            requests(2), ierror)
       ! send to bottom
       call MPI_ISSEND(in(xs,ys,zs), icount, data_type, &
            neighbour(1,6), tag_b, DECOMP_2D_COMM_CART_X, &
            requests(3), ierror)
       ! send to top
       call MPI_ISSEND(in(xs,ys,ze), icount, data_type, &
            neighbour(1,5), tag_t, DECOMP_2D_COMM_CART_X, &
            requests(4), ierror)
       call MPI_WAITALL(4, requests, status, ierror)
     else
      in(:,:,ze+1) = in(:,:,zs)
      in(:,:,zs-1) = in(:,:,ze)
     endif

#ifdef HALO_DEBUG       
          write(*,*) 'HALO COMPARISON'


          cksum = 0.0d0
          cksum2 = 0.0d0
          cksum3 = 0.0d0
          cksum4 = 0.0d0
          do i=zs,ze
            do k=xs,xe
              cksum = cksum + in(k,ys,i)
              cksum2 = cksum2 + in(k,ye,i)
              cksum3 = cksum3 + in(k,ys-1,i)
              cksum4 = cksum4 + in(k,ye+1,i)
            end do
          end do
          write(*,*) "CKSUM YS",nrank,cksum
          write(*,*) "CKSUM YE",nrank,cksum2
          write(*,*) "CKSUM YS-1",nrank,cksum3
          write(*,*) "CKSUM YE+1",nrank,cksum4

          cksum = 0.0d0
          cksum2 = 0.0d0
          cksum3 = 0.0d0
          cksum4 = 0.0d0
          do j=ys,ye
            do k=xs,xe
              cksum = cksum + in(k,j,zs)
              cksum2 = cksum2 + in(k,j,ze)
              cksum3 = cksum3 + in(k,j,zs-1)
              cksum4 = cksum4 + in(k,j,ze+1)
            end do
          end do
          write(*,*) "CKSUM ZS",nrank,cksum
          write(*,*) "CKSUM ZE",nrank,cksum2
          write(*,*) "CKSUM ZS-1",nrank,cksum3
          write(*,*) "CKSUM ZE+1",nrank,cksum4
#endif       

