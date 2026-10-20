# PROTOCOL.md — sổ đăng ký giao thức client ⇄ server (JSON qua WebSocket `ws://127.0.0.1:7172`)

> Nguồn sự thật cho client (Godot) và server. **Thêm/đổi op → ghi ở đây trong MỤC CỦA LÀN MÌNH (cuối file), không sửa mục của làn khác.**
> Gói đang chạy được liệt kê ở "Hiện hành" (trích từ code 11/10/2026). Quy ước: mọi gói là object JSON có khóa `op`.

## 0. Đăng nhập → chọn nhân vật → vào game (V13)
Mỗi kết nối bắt đầu ở "màn ngoài game": chỉ xử lý `register / login / create_char / delete_char / enter`, mọi op khác bị bỏ qua tới khi `enter` thành công. Chờ tối đa 10 phút mỗi gói.
| client → server | server → client |
|---|---|
| `register{account,password}` | `register_ok` hoặc `login_err{text}` |
| `login{account,password}` | `chars{slots:5, chars:[{slot,name,vocation,level}]}` hoặc `login_err{text}` (sai 5 lần trên 1 kết nối → ngắt; 10 lần/phút trên 1 account → khoá 1 phút) |
| `create_char{slot,name,vocation}` | `chars{...}` mới, hoặc `char_err{text}` |
| `delete_char{slot,password}` | `chars{...}` mới, hoặc `char_err{text}` (sai mật khẩu → không xoá) |
| `enter{slot}` | `hello` rồi `map`, `spells`, `backpack`, `equip`, `stats`... như cũ; hoặc `char_err{text}` |
- **Account**: 3–20 ký tự `[A-Za-z0-9_]`, không phân biệt hoa/thường; mật khẩu 6–64 ký tự, lưu scrypt+salt. `login_err` dùng chung một câu cho "không có account" và "sai mật khẩu".
- **Nhân vật**: tối đa 5/account (slot 0..4). Tên 3–16 ký tự: chữ cái (có thể `'` và `-`), cách nhau đúng 1 dấu cách, không số; duy nhất toàn server (không phân biệt hoa/thường). Nghề chọn lúc tạo, **không đổi được**.
- Cùng nhân vật vào từ kết nối thứ hai → kết nối cũ bị đá (không save đè).
- `ws://` gửi mật khẩu dạng thô: chỉ dùng cục bộ/LAN; mở ra Internet phải đặt sau `wss://`.
- Op `login{name,vocation}` kiểu cũ (V12) **đã bỏ**.

## 1. Hiện hành — client → server
| op | field | ghi chú | nơi xử lý |
|---|---|---|---|
| `register` | `account`, `password` | tạo tài khoản (trước khi vào game); xem §0 Đăng nhập | `session.pregame` |
| `login` | `account`, `password` | đăng nhập tài khoản; xem §0 | `session.pregame` |
| `create_char` | `slot` 0..4, `name`, `vocation` (1 Sorc, 2 Druid, 3 Paladin, 4 Knight) | tạo nhân vật vào slot trống | `session.pregame` |
| `delete_char` | `slot`, `password` | xoá nhân vật (nhập lại mật khẩu) | `session.pregame` |
| `enter` | `slot` | vào game bằng nhân vật ở slot; server trả `hello`... | `session.pregame` |
| `move` | `dx`,`dy` ∈ -1..1 | 1 ô/lần, cooldown 0.3s, không xuyên tường/quái | `world` |
| `goto` | `x`,`y` | server tự tìm đường (A*), kẹt thì thử lại mỗi 1s | `world` |
| `stop` | — | hủy đi/đuổi/auto/target | `world` |
| `follow` | `target`? (id quái) | đuổi theo, không đánh | `world` |
| `say` | `text` (≤120) | phát cho cả map | `net` |
| `who` | — | danh sách người chơi online | `net` |
| `attack` | `target`, `auto`? | `auto:true` = dí + đánh tới khi chết | `combat` |
| `fight` | `mode`: `attack`/`balanced`/`defense` | | `combat` |
| `cast` | `spell` (id), `target`? | | `combat` |
| `use` | `item` (id item) | ăn / mặc / đeo | `actions` |
| `learn` | `spell` (id) | học spell (đủ level + vocation + vàng) | `actions` |
| `unequip` | `slot` | | `actions` |
| `add_exp` | `exp` | **chỉ debug** (`TIBIA_DEBUG=1`), nếu không: `msg` "Debug disabled." | `vitals` |

## 2. Hiện hành — server → client
| op | field | gửi cho | ghi chú |
|---|---|---|---|
| `hello` | `id,name,x,y,z,level,exp,hp,max_hp,mana,max_mana,vocation,skills,equip,fight` `premium`, `names` (+ field do `registry.on_hello`) | chủ nhân | sau login; kế đến server gửi `map`, `spells`, `backpack`, `equip`, `stats` |
| `map` | `id,name,w,h,bg,temple,walls[],gates[{x,y,to}]` | chủ nhân | khi vào/đổi map |
| `spells` | `premium`, `spells:[{...spell, learned}]` | chủ nhân | |
| `backpack` | `items:{"<itemid>":{n,cat}}`, `names:{"<itemid>":tên}` | chủ nhân | |
| `equip` | `slots`, `counts`, `names` | chủ nhân | cũng gửi ngay sau login |
| `stats` | `id,level,exp,hp,max_hp,mana,max_mana,skills,skill_pct,maglevel,mag_pct,regen_s` | **chỉ chủ nhân** | |
| `msg` | `text` | chủ nhân hoặc cả map | thông báo chữ |
| `spawn` | `kind`(player/creature),`id,name,x,y,z,hp,max_hp`,(`map` nếu player) | cả map | |
| `leave` | `id` | cả map / toàn server khi thoát | |
| `move` | `id,x,y,z` | cả map | player đi |
| `creature_move` | `id,x,y` | cả map | |
| `creature_hp` | `id,hp` | cả map | |
| `creature_dead` | `id` | cả map | |
| `effect` | `kind`(hit/heal/death),`id`,`dmg`?,`from`? | cả map | |
| `loot` | `id`,`items:[[itemid,n]]` (đã nhặt), `left:[[itemid,n]]` (quá cân, bỏ lại), `names` | cả map | `left` mới (12/10): loot kiểm capacity; kèm `msg` "This object is too heavy for you to carry." |
| `say` | `id,text` | cả map | |
| `who` | `players:[{id,name,level}]` | người hỏi | |
| `fight` | `mode` | chủ nhân | xác nhận đổi fight mode |

## 3. Quy tắc thêm/đổi gói
1. Op client→server: `@registry.op("ten")` trong module của làn (xem `tibia_py/registry.py`); op trùng tên báo lỗi lúc import.
2. Field thêm vào `hello`: `@registry.on_hello`. Gói riêng tư (stats, thông báo skill) gửi bằng `net.send_stats` / `net.send_msg`, KHÔNG `broadcast`.
3. Không đổi tên/xóa field đang có nếu chưa báo làn D (client). Thêm field mới thì tương thích ngược (client cũ bỏ qua).
4. Mọi gói mới ghi vào mục của làn mình dưới đây, đủ: hướng, `op`, field + kiểu, gửi cho ai, ví dụ 1 dòng, trạng thái (`đề xuất` → `đã làm`).

## 4. Mục theo làn (chỉ làn đó được sửa)
### Làn A — Combat
- Không thêm op/field mới (A1). Các gói hiện có giờ do `combat.apply_damage`/`heal` phát thống nhất, **không đổi dạng**:
  `effect{kind:hit,id,dmg,from}` (`dmg` = sát thương SAU đỡ đòn, có thể 0 khi trượt/chặn hết; `from` = id người/quái gây, có thể `null` nếu không có attacker),
  `effect{kind:heal,id,dmg=lượng hồi thực,from}` (id có thể là quái), `creature_hp`, `creature_dead`, `effect{kind:death}` (chỉ player chết).
- Player chết: `effect death` → `msg` (You are dead / You lost N experience / downgraded / blessing…) → `move` về đền → `stats` (hồi đầy máu+mana). **đã làm (A3)**.
- `effect` thêm kind **`mana`** (`id`, `dmg` = mana bị mana shield nuốt, `from`): chỉ khi target có CONDITION_MANASHIELD (A5). Client cũ bỏ qua kind lạ. Trạng thái: **đã làm (server)**, đề xuất D hiển thị số xanh.
### Làn B — Monsters
- B6: loot (`loot{id,items,left,names}`, kiểm capacity) nằm ở hook `on_death` order 20 trong `mob_ai.py` (auto-loot vào túi người giết); lịch hồi sinh do `spawns.py` (B3, hook order 30).
- B2: `creature_move{id,x,y}` phát theo **tốc độ bước thật** của quái (speed lua), không còn 1 ô/giây; quái chỉ hành động khi có người trong tầm nhìn. Quái nói (voices) phát `say{id,name,text,yell}` (thêm `name`,`yell`; client cũ bỏ qua). Hồi sinh: phát lại `spawn` với **cùng id** (có thể đổi `name` nếu spawn có nhiều loại theo weight). **đã làm (server)**.
- B4 (chiêu quái, server → client): `area_fx {op, effect, tiles:[[x,y],...]}` — hiệu ứng (tên hằng CONST_ME_*) trên từng ô của vùng; `shoot_fx {op, from:[x,y], to:[x,y], effect}` — đạn bay (CONST_ANI_*); hút mana tái dùng `effect` kind `mana`; summon: server gửi `spawn` (pub của creature, có `master`), khi chết/chủ chết gửi `creature_dead {id}` (summon không hồi sinh). **đã làm (server + client V13)**: client vẽ `area_fx` thành khối màu mờ dần ~0.45s trên từng ô (tối đa 400 ô/gói) và `shoot_fx` thành chấm tròn + vệt bay (0.12–0.5s theo khoảng cách). Màu đoán theo từ khoá trong tên hằng (`Main.gd:_const_fx_color`: ICE→xanh lam, ENERGY→tím, POISON/EARTH/GREEN→xanh lá, HOLY→vàng nhạt, MORT/DEATH→tím đậm, BLOOD/RED→đỏ, BLUE/TELEPORT→xanh dương, FIRE/EXPLOSION→cam, SPEAR/ARROW/BOLT→xám; tên lạ→cam; `CONST_ME_NONE`/rỗng→không vẽ). Chưa có sprite thật — khi có, thay trong `WorldView.add_area_fx/add_shoot_fx`. **Chưa chạy thử trong Godot.**
### Làn C — Player/Items
- `stats` thêm 4 field (tương thích ngược, client cũ bỏ qua): `soul` (int), `max_soul` (int, theo vocation), `cap` (oz, số thực 2 chữ số: capacity tối đa), `free_cap` (oz: còn trống = cap − cân đồ mặc + trong túi). Trạng thái: **đã làm** (server). Client: **đã hiển thị** stamina (thanh dưới mana, h:mm, màu xanh >39:00 · cam · đỏ ≤14:00), soul (ô Soul trong Character) và cap còn trống (ô Cap); `speed` chưa hiển thị (làn D3). Server gửi lại `stats` ngay sau mỗi lần `backpack` đổi (equip/unequip/use) để `free_cap` luôn mới; loot (combat.py) đã làm tương tự và kiểm capacity (xem `loot.left`).
- `stats` thêm `stamina` (phút, 0..2520; hệ số exp 150%/100%/50% do server tính) và `speed` (tốc độ bước hiện tại; client có thể dùng để ước lượng nhịp đi). **đã làm** (server).
- Soul chỉ tăng trong 4 phút sau khi nhận exp từ quái (đúng gốc) — client chỉ cần hiển thị `soul/max_soul`.
- Dùng potion: client gửi op `use` với id item như cũ; server trừ 1, gửi lại `backpack` + `stats`, broadcast `effect` kind `heal` (potion có hồi máu) và `say` "Aaaah..." (không đổi gói). Sai level/vocation: broadcast `say` với câu mô tả, KHÔNG trừ potion. Còn cooldown: `msg` "You are exhausted.". Không trả lọ rỗng.
- `hello`/`spells`: field `premium` giữ nguyên, nay lấy từ `vitals.is_premium`.
### Làn F — Spells & Conditions
Trạng thái: `đã làm` (server) — client Godot xử lý `spells`/`cast`; `fx`, `conditions` chờ làn D vẽ. Soul nằm trong gói `stats` (làn C): `soul`, `max_soul`.

| Hướng | op | Field | Gửi cho | Ghi chú |
|---|---|---|---|---|
| C→S | `cast` | `spell:id`, `target?:creatureId` | — | như cũ; mọi spell của vocation (137 spell, xem `spell_data/SPELLS_BY_VOCATION.md`) |
| C→S | `use` | `item:id` | — | item là **rune** → bắn lên mục tiêu đang chọn (`attack`/click quái), trừ 1 charge |
| C→S | `learn` | `spell:id` | — | chỉ spell NPC bán (`needs_learn`); spell khác trả "You do not need to learn this spell." |
| S→C | `spells` | `premium`, `spells:[{id,tab,name,words,level,mana,soul,voc,prem,cd,kind,range,armor,element,desc,group,aim,price,needs_learn,learned}]` | chủ nhân | **chỉ spell hợp vocation**. `tab`: appren=tấn công, voc=hồi/hỗ trợ, prem=conjure. `kind`: heal/single/aoe/support/conjure. `aim`: self/target/target_or_dir/dir/pos |
| S→C | `fx` | `id`,`from:[x,y]`,`me?`(CONST_ME_*),`ani?`(CONST_ANI_*),`tiles?:[[x,y]..≤64]` | cả map | hiệu ứng ma thuật / đạn bay; client cũ bỏ qua |
| S→C | `say` | `id,text` | cả map | spell cast thành công hiện words trên đầu |
| C→S | `use_on` | `item:id`, `x`, `y` | — | **rune dùng lên ô đất** (Great Fireball/Bomb/Wall/Field/Magic Wall/Wild Growth/Destroy Field). Kiểm tra như Canary: tầm 7x5, đường bắn, ô có teleport, "There is not enough room.", "You can only use this rune on creatures." |
| S→C | `aim` | `item:id` | chủ nhân | `use` một rune cần ô đất mà chưa chọn quái → client vào **chế độ ngắm**: click trái chọn ô (gửi `use_on`), chuột phải/ESC hủy. Rune tường (Magic Wall/Wild Growth) luôn ngắm; rune vùng khác dùng thẳng lên ô quái đang chọn |
| S→C | `fields` | `map`, `list:[[x,y,kind,item,blocking],...]` | chủ nhân | snapshot field/tường đang có khi vào map. `kind`: fire/poison/energy/magicwall/wildgrowth |
| S→C | `field` | `map,x,y,kind,item,blocking` | cả map | field/tường mới hoặc đổi item (decayTo). `blocking=true` → tường chặn đường |
| S→C | `field_rm` | `map,x,y` | cả map | field/tường hết hạn hoặc bị Destroy Field |
| S→C | `conditions` | `id`,`list:[{t,left(ms,-1=vô hạn),level?,color?}]` | chủ nhân | haste/paralyze/manashield/invisible/light/fire/poison/... mỗi lần đổi |
| Thông báo lỗi cast (`msg`) | | "You are exhausted." / "You do not have enough level." / "You do not have enough magic level." / "You do not have enough mana." / "You do not have enough soul." / "Your vocation cannot use this spell." / "You need to learn this spell first." / "You need a premium account." / "You can only use it on creatures." / "Creature is not reachable." / "You need a magic item to cast this spell." / "This object is too heavy for you to carry." | chủ nhân | đúng chuỗi Canary |

### Làn E — NPC/Quest/Party
_(trống)_
### Core — thêm 14/10/2026
- `spawn` (kind player) có thêm `vocation` (int 1..4). `map` có thêm `pz` (bool, map là Protection Zone). Cả hai tương thích ngược.

### Làn D — Client (ghi những gì client cần thêm từ server)
- **13/10 (v11, chưa chạy thử trong Godot):** bỏ nút/phím Hit·Chase·Stop (SPACE, 1, 2, 3) khỏi client — client không còn gửi `stop`, và chỉ gửi `attack{auto:true}` khi click quái/Battle list (server vẫn giữ các op, chỉ là client không gọi từ nút nữa). Hotbar F1..F12: ô item gửi `use{item}`, ô spell gửi `cast{spell,target}` (đúng như click Túi / nút Cast). Stats HP của client nay dùng `max_hp` do server gửi (trước đây tính bằng công thức cố định).
- **Đề xuất cho làn B (tùy chọn, tương thích ngược):** `spawn` (kind creature) có thể thêm `color:[r,g,b]` (0..1) và `size` (0.5..1.0, theo ô) để client vẽ hình tạm đúng thông số quái; thiếu thì client tự suy ra từ `max_hp`. Trạng thái: **đề xuất** (client đã đọc sẵn, chưa cần server làm).
- **Đề xuất cho làn F (tùy chọn):** thêm `element` (hoặc `me` đã có) vào gói `fx` để client tô màu hiệu ứng cho cả người chơi khác/quái; hiện client chỉ tô theo element spell do CHÍNH MÌNH vừa cast (≤1.5s). Trạng thái: **đề xuất**.
- Client đã xử lý thêm (13/10, **chưa chạy thử trong Godot**): `fx` (ô hiệu ứng = khối cam mờ dần 0.45s; `ani`+`from` = chấm đạn bay tới ô xa nhất, chưa có sprite CONST_ME/ANI), `conditions` (chip chữ ngắn + màu trong panel Trạng thái, tooltip còn bao nhiêu giây), `effect kind:mana` (số xanh dương, không nháy trắng), `effect kind:death` (chữ "You are dead." giữa màn hình ~2.5s, không còn số 0 bay), `stats.speed` (dòng "Speed" trong panel Trạng thái). Client bỏ qua field lạ như cũ.

_(trống)_

### Làn E — NPC (14/10/2026, `tibia_py/npc.py`, dữ liệu `npc_data/npcs.json`)
Không hội thoại. 4 NPC đứng ở Dream Land (PZ): `npc_spell` "Spell" (bán spell), `npc_equip` "Trang bị", `npc_supply` "Vật dụng", `npc_potion` "Potion" (mua/bán đồ).
- Server -> client: `spawn` với `kind:"npc"`, `npc_type:"spell"|"shop"` (gửi lúc vào game và khi warp vào map có NPC; ô NPC chặn đường).
- Client -> server: `npc_open{id}` (mở shop, phải đứng cách <= 4 ô), `npc_buy{id,item,n}` / `npc_buy{id,spell}` (NPC Spell), `npc_sell{id,item,n}`, `npc_close{id}`. `n` bị kẹp 1..100.
- Server -> client: `npc_shop{id,name,type,gold,cap,buy:[],sell:[]}` (gửi lại sau mỗi giao dịch). `buy`/`sell` là item `{id,name,price,w,caption,vocs?,have?}` hoặc spell `{spell,name,words,price,level,prem,known,caption}` (`caption` = chú thích 1 dòng: mô tả/chỉ số/yêu cầu/cân nặng; spell: mana + mô tả). Tab Bán của 3 NPC shop liệt kê MỌI món trong túi trừ gold/platinum/crystal; giá = giá riêng của NPC -> giá bán cao nhất ở shop khác -> `default_sell`; `npc_sell` không giới hạn 100/lần (tối đa số đang có) (sell của NPC Spell rỗng); `npc_close{id}` khi đứng xa. Kèm `backpack` + `stats` mới sau mỗi giao dịch. Tiền = gold id 3031; thiếu tiền/capacity -> `msg` báo lỗi, không đổi gì.

**Thành phố + Dịch Chuyển (15/10/2026):** 4 thành phố (map `kind:"city"`, đều là PZ, mỗi nơi đủ 5 NPC: 4 NPC cũ + `Dịch Chuyển`). NPC thành phố gốc giữ id cũ (`npc_spell`...), thành phố khác id `<id>@<map>` (vd `npc_travel@hell`).
- Gói `map` thêm `theme` ("grass"|"mine"|"hell"|"desert", giao diện client) và `kind` ("city"|"hunt").
- NPC `Dịch Chuyển` (`npc_type:"teleport"`): `npc_open` -> `npc_shop{type:"teleport",buy:[{map,name,price,here}],sell:[]}`; client -> server `npc_travel{id,map}` (đứng <= 4 ô; đủ vàng; đích là thành phố khác chỗ đang đứng). Thành công: server trừ vàng, gửi `npc_close`, rồi gửi lại `map`/`spawn` như khi đi qua cổng warp (đứng ở đền thành phố đích) + `msg`. Lỗi: chỉ `msg`, không mất vàng.

### Nhà — NPC "Nhà" (Bước 3B, 18/10/2026, `tibia_py/house_npc.py` + `houses.py`)
NPC `npc_house` "Nhà" (`npc_type:"house"`, mỗi thành phố một NPC; id thành phố khác `npc_house@<map>`), đứng <= 4 ô như NPC khác.
- Client -> server: `npc_open{id}` (server trả `house_pub`, không phải `npc_shop`), `house_buy{id,house}`, `house_leave{id,house}`, `house_close{id}`. `house` là id nhà `<map>/<key>` (vd `city/n3`), chỉ nhà của thành phố có NPC đó.
- Server -> client: `house_pub{id,name,city,city_name,gold,bank,limit,owned,period_days,houses:[{...gói nhà trong `map.houses`, status}]}`, `status` = `"free"` (mua được) | `"mine"` | `"taken"` (người khác giữ) | `"limit"` (chưa có chủ nhưng account đã đủ `limit` nhà). Gửi lại sau mỗi thao tác, kèm `backpack` + `stats`.
- Mua: nhà chưa có chủ, account < `HOUSE_LIMIT_PER_ACCOUNT` (1), level >= `HOUSE_BUY_LEVEL`, (Premium nếu `HOUSE_NEED_PREMIUM`), trả `price` bằng túi trước rồi Bank. Trả nhà: chỉ chủ, không hoàn tiền, người trong nhà bị đưa ra ô trước cửa (server phát `move`). Lỗi -> `msg`, không đổi gì.
- Tiền thuê: mỗi `HOUSE_RENT_PERIOD_S` trừ từ Bank của chủ (online hoặc offline). Thiếu tiền: `msg` cảnh báo, thử lại sau `HOUSE_RENT_RETRY_S`; quá `HOUSE_RENT_MAX_WARNINGS` lần thì mất nhà. Nhà thử của god (`paid_until = 0`) không tính thuê. Xóa nhân vật nhả mọi nhà của nó.
- Khách (3E): chủ nhà `house_guest_add{id,house,name}` / `house_guest_del{id,house,name}` (mời/bỏ theo tên nhân vật, không phân biệt hoa thường; tối đa `HOUSE_MAX_GUESTS`). `house_pub.houses[].guests:[tên]` chỉ có ở nhà `status:"mine"`. Khách đi qua cửa và ngủ giường được (kể cả khi chủ offline), không sửa danh sách; bỏ khách đang ở trong nhà thì họ bị đưa ra ô trước cửa; đổi chủ/mất nhà thì danh sách về rỗng.

### Nhà — Giường + ngủ (3C, `tibia_py/beds.py`)
- Client -> server: `bed_sleep{x,y}` (ô đầu/chân giường; chủ nhà hoặc khách được mời, đang trong nhà, cách giường <= 1 ô, không đang đánh, giường chưa có người), `bed_wake{}`. Thất bại -> `msg`.
- Server -> client: `sleep{id,on}` phát cả map khi lên/xuống giường (+ `move` đưa nhân vật tới ô đầu giường, `msg`, `stats`). `spawn` của người đang ngủ có `sleeping:true`.
- Khi ngủ: mỗi `BED_APPLY_EVERY_S` giây cộng HP/mana (gấp `BED_REGEN_MULT` lần tốc độ hồi theo vocation) và +1 Soul mỗi `BED_SOUL_SECONDS` giây ngủ. Thức dậy khi: gửi `move`/`goto`/`attack`/`cast`/`use`/`use_on`/`npc_open`/`auto`/`follow` (op đó chỉ để thức dậy, không chạy tiếp), mất máu, mất quyền nhà (bị bỏ khỏi danh sách khách/mất nhà), chết, `bed_wake`, đăng xuất (cộng nốt phần hồi). Trạng thái ngủ không lưu save.

## Auto (14/10/2026) — `tibia_py/auto.py`, client `AutoPanel.gd`
Logic chạy ở server (tick order 18). Auto tắt khi: người chơi tắt, chết, đổi map, vào PZ (không bật được trong PZ).
- hello thêm `auto: {on:false, cfg, potions:[{id,name,hp:[lo,hi]|null,mp:[lo,hi]|null,level,vocs|null}], attack_runes:[id..], limits:{radius:[1,15], attack:5, support:1}}`.
- C→S `{op:"auto", on:true|false}` — bật (điểm xuất phát = ô đang đứng) / tắt.
- C→S `{op:"auto_cfg", cfg:{...}}` — đặt cấu hình (khóa cấp 1 không gửi thì giữ nguyên). `cfg`:
  `radius` 1..15 (arena vuông, Chebyshev) · `hp_pot|mp_pot:{on,item,pct 1..99}` (dùng khi % THẤP HƠN pct) ·
  `attack:{on,spells:[id..<=5]}` (xếp trước dùng trước; chỉ spell 1 mục tiêu: kind single + aim target/target_or_dir) ·
  `heal:{on,spell,pct}` (spell hồi máu bản thân) · `food:{on}` (còn <= 120s no thì ăn 1 món bất kỳ trong túi, ưu tiên món no lâu nhất mà không bị "You are full.") · `rune:{on,item}` (1 loại rune TẤN CÔNG dùng lên target, ưu tiên trước spell attack) · `support:{on,spells:[id..<=1],min_mp 1..100}` (spell conjure, cần MP% >= min_mp + còn nguyên liệu).
  Server chuẩn hóa (sai kiểu/ngoài giới hạn/sai vocation -> bỏ hoặc kẹp).
- C→S `{op:"auto_get"}` — xin lại auto_state.
- S→C `{op:"auto_state", on, cfg, origin:[x,y]|null, status:"idle|waiting|hunting|returning", reason?}` — gửi khi bật/tắt, đổi cấu hình, đổi status.
- S→C `{op:"auto_target", id}` — Auto vừa đổi target (id "" = bỏ target): client chỉ cập nhật thanh target/viền chọn, không gửi lại attack.
- Spell AOE (aim dir/pos/self) CHƯA hỗ trợ trong Auto (làm sau).

## Bản đồ thế giới (16/10/2026)
Client → `{"op":"world_map"}`. Server → `{"op":"world_map","canvas":[160,100],"maps":[{"id","name","kind","theme","w","h","x","y"}],"links":[[a,b],...]}`.
x,y = vị trí trên sơ đồ (worldmap.py LAYOUT). Vị trí hero do client tự vẽ từ `map_id` + tọa độ ô. Phím M mở/đóng.

## Mạng nhiều người (P0, netguard.py)
- Server nghe `TIBIA_HOST:TIBIA_PORT` (mặc định `0.0.0.0:7172`). Chỉ chơi máy mình: `TIBIA_HOST=127.0.0.1`.
- Giới hạn (config.NET_*): tối đa 64 kết nối (đầy -> `login_err "Máy chủ đầy"` rồi đóng); gói client→server ≤ 16 KB (quá -> đóng 1009); ~40 gói/s, burst 80 (dư bị bỏ, bỏ quá 200 lần -> ngắt); gửi cho 1 client quá 3 s -> ngắt client đó; ping/pong 20 s.
- Mật khẩu vẫn gửi nguyên văn qua `ws://`: ra Internet phải đi qua mạng riêng mã hóa (Tailscale/ZeroTier/VPN) hoặc `wss://` sau reverse proxy.

## Party (P1, party.py)
Dữ liệu chỉ sống trong phiên: thoát game = rời party. Tối đa `PARTY_MAX_MEMBERS` (10, gồm leader). Lời mời hết hạn sau 120 s.
Party "rỗng" (không member, không lời mời) tự giải tán. Leader rời -> người vào sớm nhất lên làm leader.

**Client → server**
| op | trường | ai được làm |
|---|---|---|
| `party_invite` | `name` | không ở party (tự tạo) hoặc leader |
| `party_accept` / `party_decline` | `from?` (tên leader; bỏ trống = lời mời mới nhất) | người được mời |
| `party_leave` | | thành viên |
| `party_kick` | `name` (thành viên hoặc người đang được mời) | leader |
| `party_pass` | `name` (chuyển leader) | leader |
| `party_disband` | | leader |
| `party_share` | `on?` (bỏ trống = đảo) | leader |
| `party_say` | `text` (≤120) | thành viên |
| `party_cmd` | `text` bắt đầu bằng `/`: `/party invite <tên>`, `accept [tên]`, `decline [tên]`, `leave`, `kick <tên>`, `lead <tên>`, `disband`, `share [on\|off]`, `list`, `say <chữ>`; viết tắt `/p`, `/ps <chữ>` | |

**Server → client**
- `party {id|null, leader, share, min_level, bonus, members:[{id,name,level,vocation,hp,max_hp,mana,max_mana,map,x,y,leader}], invites:[tên]}` — gửi khi đổi + mỗi 1 s; `invites` chỉ leader thấy; `id:null` = không ở party. `min_level` = ceil(level cao nhất / 1.5), `bonus` = hệ số exp theo số vocation (1→×1.2, 2→×1.3, 3→×1.6, 4→×2.0).
- `party_invite {from, from_id, party, ttl}` · `party_invite_end {party}` (lời mời xong/huỷ/hết hạn) · `party_say {from, text}` · `msg {text}` cho thông báo/lỗi.
- `spawn` của người chơi có thêm `party` (id party) và `party_leader` khi đang ở party có ≥2 người hoặc lời mời đang chờ; rời party thì phát lại `spawn` không có các trường này.
- `say` nay có thêm `name`.
Chia exp thật (`share`) làm ở P2; hiện `share` chỉ là cờ.
