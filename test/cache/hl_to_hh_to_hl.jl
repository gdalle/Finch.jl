@inbounds begin
        C_lvl = ex.cons.body.lhs.tns.tns.lvl
        C_lvl_I = C_lvl.I
        C_lvl_pos_alloc = length(C_lvl.pos)
        C_lvl_idx_alloc = length(C_lvl.idx)
        C_lvl_2 = C_lvl.lvl
        C_lvl_2_val_alloc = length(C_lvl.lvl.val)
        C_lvl_2_val = 0.0
        B_lvl = ex.cons.body.rhs.tns.tns.lvl
        B_lvl_I = B_lvl.I
        B_lvl_P = length(B_lvl.pos)
        B_lvl_pos_alloc = B_lvl_P
        B_lvl_idx_alloc = length(B_lvl.tbl)
        B_lvl_2 = B_lvl.lvl
        B_lvl_2_val_alloc = length(B_lvl.lvl.val)
        B_lvl_2_val = 0.0
        B_lvl_3 = ex.prod.body.lhs.tns.tns.lvl
        B_lvl_3_I = B_lvl_3.I
        B_lvl_3_P = length(B_lvl_3.pos)
        B_lvl_3_pos_alloc = B_lvl_3_P
        B_lvl_3_idx_alloc = length(B_lvl_3.tbl)
        B_lvl_4 = B_lvl_3.lvl
        B_lvl_4_val_alloc = length(B_lvl_3.lvl.val)
        B_lvl_4_val = 0.0
        A_lvl = ex.prod.body.rhs.tns.tns.lvl
        A_lvl_I = A_lvl.I
        A_lvl_pos_alloc = length(A_lvl.pos)
        A_lvl_idx_alloc = length(A_lvl.idx)
        A_lvl_2 = A_lvl.lvl
        A_lvl_2_val_alloc = length(A_lvl.lvl.val)
        A_lvl_2_val = 0.0
        C_lvl_I = A_lvl_I
        B_lvl_I = (A_lvl_I,)
        B_lvl_3_I = (A_lvl_I,)
        C_lvl_pos_alloc = length(C_lvl.pos)
        C_lvl.pos[1] = 1
        C_lvl_idx_alloc = length(C_lvl.idx)
        C_lvl_2_val_alloc = (Finch).refill!(C_lvl_2.val, 0.0, 0, 4)
        C_lvl_p_stop_2 = 1
        C_lvl_pos_alloc < C_lvl_p_stop_2 + 1 && (C_lvl_pos_alloc = (Finch).regrow!(C_lvl.pos, C_lvl_pos_alloc, C_lvl_p_stop_2 + 1))
        B_lvl_3_idx_alloc = 0
        empty!(B_lvl_3.tbl)
        empty!(B_lvl_3.srt)
        B_lvl_3_pos_alloc = (Finch).refill!(B_lvl_3.pos, 0, 0, 5)
        B_lvl_3.pos[1] = 1
        B_lvl_3_P = 0
        B_lvl_4_val_alloc = (Finch).refill!(B_lvl_4.val, 0.0, 0, 4)
        B_lvl_3_p_stop_2 = 1
        B_lvl_3_P = max(B_lvl_3_p_stop_2, B_lvl_3_P)
        B_lvl_3_pos_alloc < B_lvl_3_P + 1 && (B_lvl_3_pos_alloc = Finch.refill!(B_lvl_3.pos, 0, B_lvl_3_pos_alloc, B_lvl_3_P + 1))
        B_lvl_3_q = B_lvl_3.pos[1]
        A_lvl_q = A_lvl.pos[1]
        A_lvl_q_stop = A_lvl.pos[1 + 1]
        if A_lvl_q < A_lvl_q_stop
            A_lvl_i = A_lvl.idx[A_lvl_q]
            A_lvl_i1 = A_lvl.idx[A_lvl_q_stop - 1]
        else
            A_lvl_i = 1
            A_lvl_i1 = 0
        end
        i_start = 1
        i_step = min(A_lvl_i1, A_lvl_I)
        i_start_2 = i_start
        while i_start_2 <= i_step
            A_lvl_i = A_lvl.idx[A_lvl_q]
            i_step_2 = min(A_lvl_i, i_step)
            if i_step_2 == A_lvl_i
                A_lvl_2_val = A_lvl_2.val[A_lvl_q]
                i = i_step_2
                B_lvl_3_guard = true
                B_lvl_3_key = (1, (i,))
                B_lvl_3_q = get(B_lvl_3.tbl, B_lvl_3_key, B_lvl_3_idx_alloc + 1)
                if B_lvl_3_idx_alloc < B_lvl_3_q
                    B_lvl_4_val_alloc < B_lvl_3_q && (B_lvl_4_val_alloc = (Finch).refill!(B_lvl_4.val, 0.0, B_lvl_4_val_alloc, B_lvl_3_q))
                end
                B_lvl_4_val = B_lvl_4.val[B_lvl_3_q]
                B_lvl_3_guard = false
                B_lvl_3_guard = false
                B_lvl_4_val = B_lvl_4_val + A_lvl_2_val
                B_lvl_4.val[B_lvl_3_q] = B_lvl_4_val
                if !B_lvl_3_guard
                    B_lvl_3_idx_alloc = B_lvl_3_q
                    B_lvl_3.tbl[B_lvl_3_key] = B_lvl_3_idx_alloc
                    B_lvl_3.pos[1 + 1] += 1
                end
                A_lvl_q += 1
            else
            end
            i_start_2 = i_step_2 + 1
        end
        i_start = i_step + 1
        i_step = min(A_lvl_I)
        i_start = i_step + 1
        resize!(B_lvl_3.srt, length(B_lvl_3.tbl))
        copyto!(B_lvl_3.srt, pairs(B_lvl_3.tbl))
        sort!(B_lvl_3.srt)
        for B_lvl_3_p_2 = 1:B_lvl_3_P
            B_lvl_3.pos[B_lvl_3_p_2 + 1] += B_lvl_3.pos[B_lvl_3_p_2]
        end
        C_lvl_q = C_lvl.pos[1]
        B_lvl_q = B_lvl.pos[1]
        B_lvl_q_stop = B_lvl.pos[1 + 1]
        if B_lvl_q < B_lvl_q_stop
            B_lvl_i = (last(first(B_lvl.srt[B_lvl_q])))[1]
            B_lvl_i_stop = (last(first(B_lvl.srt[B_lvl_q_stop - 1])))[1]
        else
            B_lvl_i = 1
            B_lvl_i_stop = 0
        end
        i_2_start = 1
        i_2_step = min(B_lvl_i_stop, A_lvl_I)
        i_2_start_2 = i_2_start
        while i_2_start_2 <= i_2_step
            B_lvl_i = (last(first(B_lvl.srt[B_lvl_q])))[1]
            i_2_step_2 = min(B_lvl_i, i_2_step)
            if i_2_step_2 == B_lvl_i
                B_lvl_2_val = B_lvl_2.val[(last(B_lvl.srt[B_lvl_q]))[1]]
                i_2 = i_2_step_2
                C_lvl_2_val_alloc < C_lvl_q && (C_lvl_2_val_alloc = (Finch).refill!(C_lvl_2.val, 0.0, C_lvl_2_val_alloc, C_lvl_q))
                C_lvl_isdefault = true
                C_lvl_2_val = C_lvl_2.val[C_lvl_q]
                C_lvl_isdefault = false
                C_lvl_isdefault = false
                C_lvl_2_val = C_lvl_2_val + B_lvl_2_val
                C_lvl_2.val[C_lvl_q] = C_lvl_2_val
                if !C_lvl_isdefault
                    C_lvl_idx_alloc < C_lvl_q && (C_lvl_idx_alloc = (Finch).regrow!(C_lvl.idx, C_lvl_idx_alloc, C_lvl_q))
                    C_lvl.idx[C_lvl_q] = i_2
                    C_lvl_q += 1
                end
                B_lvl_q += 1
            else
            end
            i_2_start_2 = i_2_step_2 + 1
        end
        i_2_start = i_2_step + 1
        i_2_step = min(A_lvl_I)
        i_2_start = i_2_step + 1
        C_lvl.pos[1 + 1] = C_lvl_q
        (C = Fiber((Finch.HollowListLevel){Int64}(C_lvl_I, C_lvl.pos, C_lvl.idx, C_lvl_2), (Finch.Environment)(; name = :C)),)
    end
