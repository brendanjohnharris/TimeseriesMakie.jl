# ?------------------------------------------------------------------------------------------? #
# ! TEMPORARY. Delete this whole file, its `[weakdeps]`/`[extensions]`/`[compat]` entries in
# ! Project.toml, and the "Kinetic mesh anti-aliasing" test item, once CairoMakie anti-aliases a
# ! 2D mesh itself.
# !
# ! CairoMakie draws a 2D mesh by accumulating every triangle into one `Cairo.CairoPatternMesh`
# ! and then `Cairo.paint`ing it. Pattern rasterisation is not anti-aliased, so a `kinetic`
# ! stroke carrying a per-point colour comes out with hard stepped edges: two grey levels across
# ! the edge, where `lines` has six. Filling the union of the triangles as a *path*, with that
# ! same pattern as the source, is anti-aliased, keeps the per-vertex colours, and composites
# ! once for the whole mesh rather than once per 16384-patch batch.
# !
# ! This replaces `CairoMakie.draw_mesh2D`, so it changes every 2D mesh rather than only this
# ! package's. That is deliberate: it is precisely the change to submit upstream, which is what
# ! makes the file deletable in one piece. Confining it to `kinetic` alone is possible, by
# ! giving the stroke a `MetaMesh` and dispatching `draw_atomic` on the narrower plot type, but
# ! it costs more dependence on CairoMakie internals rather than less; `.claude/docs/handoff.md`
# ! has the measurements behind that choice.
# ?------------------------------------------------------------------------------------------? #
module CairoMakieAntiAliasExt

using CairoMakie

# Defined at load time rather than at top level: Julia forbids overwriting a method during
# precompilation, so an `@eval` from `__init__` is the only way to replace one. It costs a
# "Method definition ... overwritten" warning on load, which is a fair price for a patch that is
# meant to be noticed and removed.
function __init__()
    @eval CairoMakie begin
        """
            draw_mesh2D(ctx, per_face_cols, vs, fs)

        Fill the mesh rather than painting it, so that Cairo anti-aliases its boundary.

        The pattern is built exactly as upstream does, but instead of `Cairo.paint` every
        triangle is appended as a subpath and the result filled in one go. Triangles are wound
        consistently first, so the nonzero fill rule takes their union; left as they come,
        opposite windings would cancel and punch holes wherever the stroke overlaps itself.
        """
        function draw_mesh2D(
                ctx::Cairo.CairoContext, per_face_cols, vs::Vector,
                fs::Vector{GeometryBasics.GLTriangleFace}
            )
            pattern = Cairo.CairoPatternMesh()
            drawn = false
            for i in eachindex(fs)
                c1, c2, c3 = per_face_cols[i]
                t1, t2, t3 = vs[fs[i]]
                (isnan(t1) || isnan(t2) || isnan(t3)) && continue
                drawn = true
                Cairo.mesh_pattern_begin_patch(pattern)
                Cairo.mesh_pattern_move_to(pattern, t1[1], t1[2])
                Cairo.mesh_pattern_line_to(pattern, t2[1], t2[2])
                Cairo.mesh_pattern_line_to(pattern, t3[1], t3[2])
                mesh_pattern_set_corner_color(pattern, 0, c1)
                mesh_pattern_set_corner_color(pattern, 1, c2)
                mesh_pattern_set_corner_color(pattern, 2, c3)
                Cairo.mesh_pattern_end_patch(pattern)
            end
            if !drawn
                Cairo.destroy(pattern)
                return nothing
            end

            Cairo.set_source(ctx, pattern)
            Cairo.new_path(ctx)
            for i in eachindex(fs)
                t1, t2, t3 = vs[fs[i]]
                (isnan(t1) || isnan(t2) || isnan(t3)) && continue
                turn = (t2[1] - t1[1]) * (t3[2] - t1[2]) - (t2[2] - t1[2]) * (t3[1] - t1[1])
                p, q, r = turn >= 0 ? (t1, t2, t3) : (t1, t3, t2)
                Cairo.move_to(ctx, p[1], p[2])
                Cairo.line_to(ctx, q[1], q[2])
                Cairo.line_to(ctx, r[1], r[2])
                Cairo.close_path(ctx)
            end
            Cairo.fill(ctx)

            Cairo.destroy(pattern)
            Cairo.set_source_rgba(ctx, 0, 0, 0, 1) # upstream resets this after painting
            return nothing
        end
    end
    return nothing
end

end
