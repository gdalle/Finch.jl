begin
    B_lvl = ex.body.lhs.tns.tns.lvl
    B_lvl_2 = B_lvl.lvl
    B_lvl_2_val = 0.0
    A_lvl = ex.body.rhs.tns.tns.lvl
    resize_if_smaller!(B_lvl_2.val, A_lvl.I)
    fill_range!(B_lvl_2.val, 0.0, 1, A_lvl.I)
    A_lvl_q = A_lvl.pos[1]
    A_lvl_q_stop = A_lvl.pos[1 + 1]
    if A_lvl_q < A_lvl_q_stop
        A_lvl_i = A_lvl.idx[A_lvl_q]
        A_lvl_i1 = A_lvl.idx[A_lvl_q_stop - 1]
    else
        A_lvl_i = 1
        A_lvl_i1 = 0
    end
    i = 1
    while A_lvl_q + 1 < A_lvl_q_stop && A_lvl.idx[A_lvl_q] < 1
        A_lvl_q += 1
    end
    while i <= A_lvl.I
        i_start = i
        A_lvl_i = A_lvl.idx[A_lvl_q]
        phase_stop = (