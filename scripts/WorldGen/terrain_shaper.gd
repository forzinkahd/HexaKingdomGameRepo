class_name TerrainShaper

# Biome-based height mapping. Replaces the single height_curve approach
# with three distinct zones: plains, hills, mountains.
# All thresholds are exposed in GenerationSettings for tuning.

static func assign_height(v: Voxel, t: float, settings: GenerationSettings) -> void:
	# t: normalized noise [0..1], already computed by GridMapper
	var sea := settings.sea_level_units

	# Port face override: force a swath of tiles along one hex face to sea level
	if settings.port_face_enabled:
		var dist := _dist_to_port_face(v, settings)
		if dist <= 0:
			v.height_units = sea
			return
		elif dist <= settings.port_face_depth:
			# Gradient: low plains near port, transitions inward
			var blend := float(dist) / float(settings.port_face_depth)
			v.height_units = sea + int(round(blend * float(settings.plains_max_height_units - sea)))
			_quantize(v, settings)
			return

	# Buffer tiles: very low but above sea so they get land caps
	if v.buffer:
		v.height_units = sea + 1
		return

	var h: int

	if t < settings.plains_threshold:
		# Plains zone: flat and buildable.
		# Compress height into a narrow band above sea level.
		var local_t : Variant = t / settings.plains_threshold
		var range_h : Variant = max(1, settings.plains_max_height_units - sea - 1)
		h = sea + 1 + int(round(local_t * float(range_h)))

	elif t < settings.hills_threshold:
		# Hills zone: gradual increase. Use a mild exponent for rolling feel.
		var local_t : Variant = (t - settings.plains_threshold) / (settings.hills_threshold - settings.plains_threshold)
		local_t = pow(local_t, 1.4)
		var from_h := settings.plains_max_height_units + 1
		var range_h : Variant = max(0, settings.hills_max_height_units - from_h)
		h = from_h + int(round(local_t * float(range_h)))

	else:
		# Mountain zone: sharp peaks.
		var local_t : Variant = (t - settings.hills_threshold) / (1.0 - settings.hills_threshold)
		local_t = pow(local_t, settings.height_curve / 3.0)
		var from_h := settings.hills_max_height_units + 1
		var range_h : Variant = max(0, settings.max_height_units - from_h)
		h = from_h + int(round(local_t * float(range_h)))

		# Extra cliff boost in mountain zone
		if t > settings.cliff_threshold:
			h = min(settings.max_height_units, h + settings.cliff_boost_units)

	v.height_units = clampi(h, sea, settings.max_height_units)
	_quantize(v, settings)


static func _quantize(v: Voxel, settings: GenerationSettings) -> void:
	var q : Variant = max(1, settings.terrace_quantum_units)
	v.height_units = int(round(float(v.height_units) / float(q))) * q
	v.height_units = clampi(v.height_units, settings.sea_level_units, settings.max_height_units)


# Distance (in hex steps) from tile to the designated port face.
# Returns 0 if on the face, negative if outside, positive if interior.
static func _dist_to_port_face(v: Voxel, settings: GenerationSettings) -> int:
	var q := v.grid_position_xz.x
	var r := v.grid_position_xz.y
	var R := settings.radius
	match settings.port_face_direction:
		0: return R - q          # NE face: q = R
		1: return R - r          # SE face: r = R
		2: return (q + r) + R    # SW face: q + r = -R
		3: return q + R          # W face:  q = -R
		4: return r + R          # NW face: r = -R
		5: return R - (q + r)    # E face:  q + r = R
		_: return R
