@inbounds begin
        A_lvl = ex.body.lhs.tns.tns.lvl
        A_lvl_I = A_lvl.I
        A_lvl_pos_alloc = length(A_lvl.pos)
        A_lvl_idx_alloc = length(A_lvl.idx)
        A_lvl_2 = A_lvl.lvl
        A_lvl_2_val_alloc = length(A_lvl.lvl.val)
        A_lvl_2_val = 0.0
        B_lvl = ex.body.rhs.tns.tns.lvl
        B_lvl_I = B_lvl.I
        B_lvl_P = length(B_lvl.pos)
        B_lvl_pos_alloc = B_lvl_P
        B_lvl_idx_alloc = length(B_lvl.tbl)
        B_lvl_2 = B_lvl.lvl
        B_lvl_2_val_alloc = length(B_lvl.lvl.val)
        B_lvl_2_val = 0.0
        A_lvl_I = B_lvl_I[1]
        A_lvl_pos_alloc = length(A_lvl.pos)
        A_lvl.pos[1] = 1
        A_lvl_idx_alloc = length(A_lvl.idx)
        A_lvl_2_val_alloc = (Finch).refill!(A_lvl_2.val, 0.0, 0, 4)
        A_lvl_p_stop_2 = 1
        A_lvl_pos_alloc < A_lvl_p_stop_2 + 1 && (A_lvl_pos_alloc = (Finch).regrow!(A_lvl.pos, A_lvl_pos_alloc, A_lvl_p_stop_2 + 1))
        A_lvl_q = A_lvl.pos[1]
        B_lvl_q = B_lvl.pos[1]
        B_lvl_q_stop = B_lvl.pos[1 + 1]
        if B_lvl_q < B_lvl_q_stop
            B_lvl_i = (last(first(B_lvl.srt[B_lvl_q])))[1]
            B_lvl_i_stop = (last(first(B_lvl.srt[B_lvl_q_stop - 1])))[1]
        else
            B_lvl_i = 1
            B_lvl_i_stop = 0
        end
        i_start = 1
        i_step = min(B_lvl_i_stop, B_lvl_I[1])
        i_start_2 = i_start
        while i_start_2 <= i_step
            B_lvl_i = (last(first(B_lvl.srt[B_lvl_q])))[1]
            i_step_2 = min(B_lvl_i, i_step)
            if i_step_2 == B_lvl_i
                B_lvl_2_val = B_lvl_2.val[(last(B_lvl.srt[B_lvl_q]))[1]]
                i = i_step_2
                A_lvl_2_val_alloc < A_lvl_q && (A_lvl_2_val_alloc = (Finch).refill!(A_lvl_2.val, 0.0, A_lvl_2_val_alloc, A_lvl_q))
                A_lvl_isdefault = true
                A_lvl_2_val = A_lvl_2.val[A_lvl_q]
                A_lvl_isdefault = false
                A_lvl_isdefault = false
                A_lvl_2_val = A_lvl_2_val + B_lvl_2_val
                A_lvl_2.val[A_lvl_q] = A_lvl_2_val
                if !A_lvl_isdefault
                    A_lvl_idx_alloc < A_lvl_q && (A_lvl_idx_alloc = (Finch).regrow!(A_lvl.idx, A_lvl_idx_alloc, A_lvl_q))
                    A_lvl.idx[A_lvl_q] = i
                    A_lvl_q += 1
                end
                B_lvl_q += 1
            else
            end
            i_start_2 = i_step_2 + 1
        end
        i_start = i_step + 1
        i_step = min(B_lvl_I[1])
        i_start = i_step + 1
        A_lvl.pos[1 + 1] = A_lvl_q
        (A = Fiber((Finch.HollowListLevel){Int64}(A_lvl_I, A_lvl.pos, A_lvl.idx, A_lvl_2), (Finch.Environment)(; name = :A)),)
    end
