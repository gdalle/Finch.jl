begin
    C_lvl = ex.body.body.lhs.tns.tns.lvl
    C_lvl_2 = C_lvl.lvl
    A_lvl = ((ex.body.body.rhs.args[1]).args[1]).tns.tns.lvl
    A_lvl_2 = A_lvl.lvl
    A_lvl_3 = ((ex.body.body.rhs.args[2]).args[1]).tns.tns.lvl
    A_lvl_4 = A_lvl_3.lvl
    F_lvl = (ex.body.body.rhs.args[3]).tns.tns.lvl
    F_lvl_2 = F_lvl.lvl
    C_lvl_qos_fill = 0
    C_lvl_qos_stop = 0
    (Finch.resize_if_smaller!)(C_lvl.pos, 1 + 1)
    (Finch.fill_range!)(C_lvl.pos, 0, 1 + 1, 1 + 1)
    C_lvl_qos = C_lvl_qos_fill + 1
    A_lvl_q = A_lvl.pos[1]
    A_lvl_q_stop = A_lvl.pos[1 + 1]
    A_lvl_i = if A_lvl_q < A_lvl_q_stop
            A_lvl.idx[A_lvl_q]
        else
            1
        end
    A_lvl_i1 = if A_lvl_q < A_lvl_q_stop
            A_lvl.idx[A_lvl_q_stop - 1]
        else
            0
        end
    i = 1
    i_start = i
    phase_stop = (min)(A_lvl.I, A_lvl_i1)
    if phase_stop >= i_start
        i = i
        i = i_start
        while A_lvl_q + 1 < A_lvl_q_stop && A_lvl.idx[A_lvl_q] < i_start
            A_lvl_q += 1
        end
        while i <= phase_stop
            i_start_2 = i
            A_lvl_i = A_lvl.idx[A_lvl_q]
            phase_stop_2 = (min)(A_lvl_i, phase_stop)
            i_2 = i
            if A_lvl_i == phase_stop_2
                A_lvl_2_val_2 = A_lvl_2.val[A_lvl_q]
                i_3 = phase_stop_2
                if C_lvl_qos > C_lvl_qos_stop
                    C_lvl_qos_stop = max(C_lvl_qos_stop << 1, 1)
                    (Finch.resize_if_smaller!)(C_lvl.idx, C_lvl_qos_stop)
                    resize_if_smaller!(C_lvl_2.val, C_lvl_qos_stop)
                    fill_range!(C_lvl_2.val, 0.0, C_lvl_qos, C_lvl_qos_stop)
                end
                C_lvl_2_dirty = false
                C_lvl_2_val_2 = C_lvl_2.val[C_lvl_qos]
                s_2 = (+)(-3, i_3)
                for s_3 = s_2:s_2
                    j = 1
                    j_start = j
                    phase_stop_3 = (min)(F_lvl.I, s_3)
                    if phase_stop_3 >= j_start
                        j = j
                        j = phase_stop_3 + 1
                    end
                    j_start = j
                    phase_stop_4 = (min)(F_lvl.I, (+)(A_lvl.I, s_3))
                    if phase_stop_4 >= j_start
                        j_2 = j
                        A_lvl_q_2 = A_lvl.pos[1]
                        A_lvl_q_stop_2 = A_lvl.pos[1 + 1]
                        A_lvl_i_2 = if A_lvl_q_2 < A_lvl_q_stop_2
                                A_lvl.idx[A_lvl_q_2]
                            else
                                1
                            end
                        A_lvl_i1_2 = if A_lvl_q_2 < A_lvl_q_stop_2
                                A_lvl.idx[A_lvl_q_stop_2 - 1]
                            else
                                0
                            end
                        j = j_start
                        j_start_2 = j
                        phase_start = (max)(j_start_2, (+)(s_3, j_start_2, (-)(s_3)))
                        phase_stop_5 = (min)(phase_stop_4, (+)(s_3, A_lvl_i1_2))
                        if phase_stop_5 >= phase_start
                            j_3 = j
                            j = phase_start
                            while A_lvl_q_2 + 1 < A_lvl_q_stop_2 && A_lvl.idx[A_lvl_q_2] < (+)(phase_start, (-)(s_3))
                                A_lvl_q_2 += 1
                            end
                            while j <= phase_stop_5
                                j_start_3 = j
                                A_lvl_i_2 = A_lvl.idx[A_lvl_q_2]
                                phase_start_2 = (max)(j_start_3, (+)(s_3, (-)(s_3), j_start_3))
                                phase_stop_6 = (min)(phase_stop_5, (+)(s_3, A_lvl_i_2))
                                if phase_stop_6 >= phase_start_2
                                    j_4 = j
                                    if A_lvl_i_2 == (+)(phase_stop_6, (-)(s_3))
                                        A_lvl_2_val_3 = A_lvl_2.val[A_lvl_q_2]
                                        j_5 = phase_stop_6
                                        F_lvl_q = (1 - 1) * F_lvl.I + j_5
                                        F_lvl_2_val_2 = F_lvl_2.val[F_lvl_q]
                                        C_lvl_2_dirty = true
                                        C_lvl_2_dirty = true
                                        C_lvl_2_val_2 = (+)((*)((!=)(A_lvl_2_val_2, 0), F_lvl_2_val_2, (coalesce)(A_lvl_2_val_3, 0)), C_lvl_2_val_2)
                                        A_lvl_q_2 += 1
                                    else
                                    end
                                    j = phase_stop_6 + 1
                                end
                            end
                            j = phase_stop_5 + 1
                        end
                        j_start_2 = j
                        phase_start_3 = (max)(j_start_2, (+)(s_3, j_start_2, (-)(s_3)))
                        phase_stop_7 = (min)(phase_stop_4, (+)(s_3, (-)(s_3), phase_stop_4))
                        if phase_stop_7 >= phase_start_3
                            j_6 = j
                            j = phase_stop_7 + 1
                        end
                        j = phase_stop_4 + 1
                    end
                    j_start = j
                    if F_lvl.I >= j_start
                        j_7 = j
                        j = F_lvl.I + 1
                    end
                end
                C_lvl_2.val[C_lvl_qos] = C_lvl_2_val_2
                if C_lvl_2_dirty
                    C_lvl_dirty = true
                    C_lvl.idx[C_lvl_qos] = i_3
                    C_lvl_qos += 1
                end
                A_lvl_q += 1
            else
            end
            i = phase_stop_2 + 1
        end
        i = phase_stop + 1
    end
    i_start = i
    if A_lvl.I >= i_start
        i_4 = i
        i = A_lvl.I + 1
    end
    C_lvl.pos[1 + 1] = (C_lvl_qos - C_lvl_qos_fill) - 1
    C_lvl_qos_fill = C_lvl_qos - 1
    for p = 2:1 + 1
        C_lvl.pos[p] += C_lvl.pos[p - 1]
    end
    qos_stop = C_lvl.pos[1 + 1] - 1
    resize!(C_lvl.pos, 1 + 1)
    qos = C_lvl.pos[end] - 1
    resize!(C_lvl.idx, qos)
    resize!(C_lvl_2.val, qos)
    (C = Fiber((Finch.SparseListLevel){Int64}(A_lvl.I, C_lvl.pos, C_lvl.idx, C_lvl_2)),)
end