extends AnimatedSprite2D

#region Signals (Tín hiệu tùy chỉnh)
signal not_enough_energy(required_energy: float, current_energy: float)
signal action_completed(action_name: String) # THÊM MỚI: Tín hiệu khi hành động hoàn thành
#endregion

#region Peppa's Stats
@export var hunger: float = 100.0   # Mức độ đói (0-100)
@export var happiness: float = 100.0 # Mức độ hạnh phúc (0-100)
@export var alertness: float = 100.0 # Mức độ tỉnh táo (0-100)
@export var cleanliness: float = 100.0 # Mức độ sạch sẽ (0-100)

const MAX_ENERGY: float = 300.0
@export var energy: float = MAX_ENERGY

# Các biến chỉ số mục tiêu để tăng dần từ từ
var target_hunger: float
var target_happiness: float
var target_alertness: float
var target_cleanliness: float


var is_affected_by_rain: bool = false
# KHÔNG CÓ BIẾN THEO DÕI TRẠNG THÁI MƯA Ở ĐÂY
#endregion

#region Stat Change Rates (Tốc độ thay đổi chỉ số)
const HUNGER_DECAY_RATE: float = 0.5
const HAPPINESS_DECAY_RATE: float = 0.3
const ALERTNESS_DECAY_RATE: float = 0.4
const CLEANLINESS_DECAY_RATE: float = 0.2

const ENERGY_REGEN_RATE_PER_SECOND: float = 1.0 / 60.0

const ACTION_COOLDOWN: float = 1.0

const EAT_TO_AFTEREAT_DELAY: float = 5.0
# ĐẶT LẠI: Độ trễ sau hành động là 2 giây như cũ
const POST_ACTION_DELAY: float = 2.0

# Tốc độ thay đổi chỉ số (điểm mỗi giây)
const STAT_CHANGE_SPEED: float = 15.0 # Điều chỉnh giá trị này để chỉ số tăng nhanh/chậm

# Một giá trị nhỏ để so sánh số thực (tránh lỗi làm tròn)
const EPSILON: float = 0.05 # Nếu chỉ số và mục tiêu chênh lệch ít hơn giá trị này, coi là đã đạt.

var is_action_animation_active: bool = false
var current_action_cooldown: float = 0.0

var is_sick: bool = false
const SICKNESS_THRESHOLD_CLEANLINESS: float = 10.0
const SICKNESS_THRESHOLD_HAPPINESS: float = 15.0
const SICKNESS_AFFECT_RATE: float = 0.2
#endregion

const ACTION_ENERGY_COST: float = 10.0

func _ready():
	play("delight")
	# Khởi tạo các chỉ số mục tiêu bằng chỉ số hiện tại
	target_hunger = hunger
	target_happiness = happiness
	target_alertness = alertness
	target_cleanliness = cleanliness
	print("Peppa: _ready. Current animation:", animation)

func _process(delta):
	# Hồi phục năng lượng theo thời gian
	energy += ENERGY_REGEN_RATE_PER_SECOND * delta

	# Luôn giảm dần các chỉ số theo thời gian (Decay)
	# Việc này áp dụng cho chỉ số hiện tại trước
	hunger -= HUNGER_DECAY_RATE * delta
	happiness -= HAPPINESS_DECAY_RATE * delta
	alertness -= ALERTNESS_DECAY_RATE * delta
	cleanliness -= CLEANLINESS_DECAY_RATE * delta

	# Logic mới cho việc tăng/giảm chỉ số mượt mà (GIỮ LẠI PHẦN NÀY)
	if hunger < target_hunger - EPSILON:
		hunger = lerp(hunger, target_hunger, STAT_CHANGE_SPEED * delta)
	elif hunger > target_hunger + EPSILON: # Trường hợp đặc biệt nếu chỉ số hiện tại cao hơn mục tiêu
		target_hunger = hunger # Mục tiêu theo sát chỉ số để chỉ số có thể giảm tự nhiên
	else: # Nếu chỉ số hiện tại và mục tiêu đã gần nhau
		target_hunger = hunger # Đảm bảo mục tiêu khớp với chỉ số để decay hoạt động

	if happiness < target_happiness - EPSILON:
		happiness = lerp(happiness, target_happiness, STAT_CHANGE_SPEED * delta)
	elif happiness > target_happiness + EPSILON:
		target_happiness = happiness
	else:
		target_happiness = happiness

	if alertness < target_alertness - EPSILON:
		alertness = lerp(alertness, target_alertness, STAT_CHANGE_SPEED * delta)
	elif alertness > target_alertness + EPSILON:
		target_alertness = alertness
	else:
		target_alertness = alertness

	if cleanliness < target_cleanliness - EPSILON:
		cleanliness = lerp(cleanliness, target_cleanliness, STAT_CHANGE_SPEED * delta)
	elif cleanliness > target_cleanliness + EPSILON:
		target_cleanliness = cleanliness
	else:
		target_cleanliness = cleanliness

	# Đảm bảo các chỉ số nằm trong khoảng hợp lệ (0-100) sau khi decay và lerp
	hunger = clamp(hunger, 0.0, 100.0)
	happiness = clamp(happiness, 0.0, 100.0)
	alertness = clamp(alertness, 0.0, 100.0)
	cleanliness = clamp(cleanliness, 0.0, 100.0)
	energy = clamp(energy, 0.0, MAX_ENERGY)

	# Kiểm tra trạng thái ốm
	check_sickness()

	# Nếu đang ốm, giảm các chỉ số nhanh hơn
	if is_sick:
		hunger = max(0, hunger - SICKNESS_AFFECT_RATE * delta)
		happiness = max(0, happiness - SICKNESS_AFFECT_RATE * delta)
		alertness = max(0, alertness - SICKNESS_AFFECT_RATE * delta)
		cleanliness = max(0, cleanliness - SICKNESS_AFFECT_RATE * delta)

	# Giảm thời gian hồi chiêu cho các nút bấm
	if current_action_cooldown > 0:
		current_action_cooldown -= delta

	# Chỉ cập nhật hoạt ảnh cảm xúc nếu không có hoạt ảnh hành động/sau hành động đang diễn ra
	if not is_action_animation_active:
		update_emotional_animation()


func check_sickness():
	var should_be_sick = false
	if cleanliness <= SICKNESS_THRESHOLD_CLEANLINESS:
		should_be_sick = true
	if happiness <= SICKNESS_THRESHOLD_HAPPINESS:
		should_be_sick = true

	if should_be_sick and not is_sick:
		is_sick = true
		print("Peppa bị ốm rồi!")
		update_emotional_animation()
	elif not should_be_sick and is_sick:
		is_sick = false
		print("Peppa đã khỏe lại!")
		update_emotional_animation()

# CẬP NHẬT HOẠT ẢNH CẢM XÚC (KHÔNG CÓ LOGIC MƯA Ở ĐÂY)
func update_emotional_animation():
	var new_animation = "delight"

	if is_sick:
		new_animation = "sick"
	elif hunger <= 20:
		new_animation = "cry"
	elif alertness <= 20:
		new_animation = "sleepy"
	elif cleanliness <= 20:
		new_animation = "dirty"
	elif happiness <= 20:
		new_animation = "crying"
	elif hunger >= 80 and happiness >= 80 and alertness >= 80 and cleanliness >= 80:
		new_animation = "happy"
	else:
		new_animation = "delight"

	if animation != new_animation:
		play(new_animation)


func _set_action_animation_state(active: bool):
	is_action_animation_active = active
	print("Peppa: Setting is_action_animation_active to", active)


func _try_perform_action(action_name: String):
	if current_action_cooldown > 0:
		print("Peppa: ", action_name, " button on cooldown. Remaining:", current_action_cooldown)
		return false

	if energy < ACTION_ENERGY_COST:
		print("Peppa: Không đủ năng lượng để ", action_name, "! Cần: ", ACTION_ENERGY_COST, ", Hiện có: ", energy)
		emit_signal("not_enough_energy", ACTION_ENERGY_COST, energy)
		return false
	
	energy -= ACTION_ENERGY_COST
	current_action_cooldown = ACTION_COOLDOWN
	print("Peppa: ", action_name, " action triggered! Năng lượng còn lại: ", energy)
	_set_action_animation_state(true)
	return true


#region Các hàm tương tác với Peppa
func feed():
	# Hàm feed này giờ chỉ dùng để kích hoạt hoạt ảnh ăn và delay.
	# Việc thay đổi chỉ số đã được chuyển sang hàm consume_food().
	if _try_perform_action("Feed"):
		play("eat")
		print("Peppa: Playing 'eat' animation.")
		
		animation_finished.connect(func():
			print("Peppa: 'animation_finished' signal received for 'eat'. Current animation is now:", animation)
			if animation == "eat":
				print("Peppa: 'eat' animation finished. Starting", EAT_TO_AFTEREAT_DELAY, "s delay before 'aftereat'.")
				get_tree().create_timer(EAT_TO_AFTEREAT_DELAY).timeout.connect(func():
					play("aftereat")
					print("Peppa: Delay finished. Playing 'aftereat' animation.")
					
					animation_finished.connect(func():
						print("Peppa: 'animation_finished' signal received for 'aftereat'. Current animation is now:", animation)
						if animation == "aftereat":
							print("Peppa: 'aftereat' animation finished. Starting", POST_ACTION_DELAY, "s post-action timer.")
							get_tree().create_timer(POST_ACTION_DELAY).timeout.connect(func():
								print("Peppa: Post-action timer finished. Allowing emotional update.")
								_set_action_animation_state(false)
								emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu sau khi hành động hoàn tất
							)
						else:
							print("Peppa: Warning: animation_finished received but current animation is not 'aftereat'. It's:", animation)
							_set_action_animation_state(false)
							emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
					, CONNECT_ONE_SHOT)
				)
			else:
				print("Peppa: Warning: animation_finished received but current animation is not 'eat'. It's:", animation)
				_set_action_animation_state(false)
				emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
		, CONNECT_ONE_SHOT)

# HÀM MỚI: Dùng để thay đổi chỉ số khi Peppa ăn đồ ăn từ menu
func consume_food(hunger_increase: float, happiness_gain: float):
	if _try_perform_action("Consume Food"): # Vẫn tốn năng lượng cho hành động này
		target_hunger = min(100.0, target_hunger + hunger_increase)
		target_happiness = min(100.0, target_happiness + happiness_gain)
		print("Peppa đã ăn! Hunger +", hunger_increase, ", Happiness +", happiness_gain)
		play("eat")
		print("Peppa: Playing 'eat' animation.")
		animation_finished.connect(func():
			if animation == "eat":
				print("Peppa: 'eat' animation finished. Starting", EAT_TO_AFTEREAT_DELAY, "s delay before 'aftereat'.")
				get_tree().create_timer(EAT_TO_AFTEREAT_DELAY).timeout.connect(func():
					play("aftereat")
					print("Peppa: Delay finished. Playing 'aftereat' animation.")
					
					animation_finished.connect(func():
						print("Peppa: 'animation_finished' signal received for 'aftereat'. Current animation is now:", animation)
						if animation == "aftereat":
							print("Peppa: 'aftereat' animation finished. Starting", POST_ACTION_DELAY, "s post-action timer.")
							get_tree().create_timer(POST_ACTION_DELAY).timeout.connect(func():
								print("Peppa: Post-action timer finished. Allowing emotional update.")
								_set_action_animation_state(false)
								emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu sau khi hành động hoàn tất
							)
						else:
							print("Peppa: Warning: animation_finished received but current animation is not 'aftereat'. It's:", animation)
							_set_action_animation_state(false)
							emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
					, CONNECT_ONE_SHOT)
				)
			else:
				print("Peppa: Warning: animation_finished received but current animation is not 'eat'. It's:", animation)
				_set_action_animation_state(false)
				emit_signal("action_completed", "feed") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
		, CONNECT_ONE_SHOT)

func play_with():
	if _try_perform_action("Play"):
		# Cộng vào target_happiness và trừ vào target_alertness/target_cleanliness
		target_happiness = min(100.0, target_happiness + 30.0)
		target_alertness = max(0.0, target_alertness - 10.0) # Vẫn giữ giảm alertness sau khi chơi
		target_cleanliness = max(0.0, target_cleanliness - 15.0) # Vẫn giữ giảm cleanliness sau khi chơi
		
		play("play")
		print("Peppa: Playing 'play' animation.")
		
		animation_finished.connect(func():
			print("Peppa: 'animation_finished' signal received for 'play'. Current animation is now:", animation)
			if animation == "play":
				print("Peppa: 'play' animation finished. Starting", POST_ACTION_DELAY, "s post-action timer.")
				get_tree().create_timer(POST_ACTION_DELAY).timeout.connect(func():
					print("Peppa: Post-action timer finished. Allowing emotional update.")
					_set_action_animation_state(false)
					emit_signal("action_completed", "play") # THÊM MỚI: Phát tín hiệu sau khi hành động hoàn tất
				)
			else:
				print("Peppa: Warning: animation_finished received but current animation is not 'play'. It's:", animation)
				_set_action_animation_state(false)
				emit_signal("action_completed", "play") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
		, CONNECT_ONE_SHOT)

func bathe():
	if _try_perform_action("Bathe"):
		# Cộng vào target_cleanliness và target_happiness
		target_cleanliness = min(100.0, target_cleanliness + 40.0)
		target_happiness = min(100.0, target_happiness + 5.0)
		
		play("bath")
		print("Peppa: Playing 'bath' animation.")
		
		animation_finished.connect(func():
			print("Peppa: 'animation_finished' signal received for 'bath'. Current animation is now:", animation)
			if animation == "bath":
				print("Peppa: 'bath' animation finished. Starting", POST_ACTION_DELAY, "s post-action timer.")
				get_tree().create_timer(POST_ACTION_DELAY).timeout.connect(func():
					print("Peppa: Post-action timer finished. Allowing emotional update.")
					_set_action_animation_state(false)
					emit_signal("action_completed", "bathe") # THÊM MỚI: Phát tín hiệu sau khi hành động hoàn tất
				)
			else:
				print("Peppa: Warning: animation_finished received but current animation is not 'bath'. It's:", animation)
				_set_action_animation_state(false)
				emit_signal("action_completed", "bathe") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
		, CONNECT_ONE_SHOT)

func sleep():
	if current_action_cooldown > 0:
		print("Peppa: Sleep button on cooldown. Remaining:", current_action_cooldown)
		return
	
	# Ngủ không tốn năng lượng, mà hồi phục. Nên không dùng _try_perform_action trực tiếp ở đây.
	# Nhưng vẫn có cooldown.

	print("Peppa: Sleep action triggered!")
	_set_action_animation_state(true)
	current_action_cooldown = ACTION_COOLDOWN

	# Cộng vào target_alertness và target_happiness
	target_alertness = min(100.0, target_alertness + 50.0)
	target_happiness = min(100.0, target_happiness + 5.0)
	
	play("sleep")
	print("Peppa: Playing 'sleep' animation.")
	
	animation_finished.connect(func():
		print("Peppa: 'animation_finished' signal received for 'sleep'. Current animation is now:", animation)
		if animation == "sleep":
			print("Peppa: 'sleep' animation finished. Starting", POST_ACTION_DELAY, "s post-action timer.")
			get_tree().create_timer(POST_ACTION_DELAY).timeout.connect(func():
				print("Peppa: Post-action timer finished. Allowing emotional update.")
				_set_action_animation_state(false)
				emit_signal("action_completed", "sleep") # THÊM MỚI: Phát tín hiệu sau khi hành động hoàn tất
			)
		else:
			print("Peppa: Warning: animation_finished received but current animation is not 'sleep'. It's:", animation)
			_set_action_animation_state(false)
			emit_signal("action_completed", "sleep") # THÊM MỚI: Phát tín hiệu ngay cả khi có cảnh báo
	, CONNECT_ONE_SHOT)
#endregion
