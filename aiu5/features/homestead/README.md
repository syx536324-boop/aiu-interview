# 提水、农田、烹饪与户外部署

`homestead.gd` 入口 `start(world, interiors, inventory)`；`fill_bucket`、`till`、`water`、`plant`、`harvest`、`stove` 处理会话转交的动作，库存通过 `exchange` 事务改变。`select_seed` 按角色稳定ID记住种子，湿润空田附近同时播种；`cultivate` 将G转为播种或成熟收获。每个16×16田格消耗1种子、收获1谷物加2颗对应种子，两项奖励原子入包，空间不足则保留庄稼。

`crop_catalog.gd` 定义小麦/水稻、种子/收获物和四个120秒阶段；0–120萌芽、120–240幼苗、240–360拔节、360–480结穗，480秒完成第四阶段成熟。`advance(seconds)` 独立推进湿润地块的生长、灌溉年龄及60秒烹饪，只计算在线时间。灌溉只重置缺水时钟，超过7200秒则死苗，重新灌溉清除死苗及生长进度。`refresh` 生成渲染所需阶段/成熟标志；`nearby(actor)` 提供物种、阶段、倒计时及动作提示。`land.gd` 只绘制土壤、两类四阶段植株、成熟金穗、死苗和湖泊；`kitchen_detail.gd` 绘制灶房烟囱。

`export_state` / `restore` 保存地块类型、生长秒数、灌溉年龄及各角色种子选择；旧`seedling`按小麦0秒兼容，原`seeds`物品ID保留。主入口不添加作物计算；会话负责输入与保存，界面只呈现快照。边界与存档验证见 `tests/crops_smoke.gd`。

`fill_bucket(actor)` 保留兼容入口名，在水源E互动时装满当前背包所有空/部分桶与空木质水杯，已满容器不变，整次库存事务失败不改变任何容器。`water(actor)` 只接受原`water_bucket`（4/4），消耗完整桶并返还空桶，从选中格起沿上下左右相连田格广度扩散，最多15格；不足15格仍消耗完整桶，部分桶和杯均不灌溉；饮水规则归survival。验证见 `tests/water_smoke.gd`。

`grounds.gd` 适配家具编辑器的放置/移动/删除接口，在村落objects中添加工作台与围栏的真实碰撞。`placement_error` 检查已有建筑、村民、农田、猪圈、设施门口和原有可达通路，`land_error` 同时供锄地使用。部署记录以 `outdoors` 布局保存，拆除返还物品；工作台配方由mining提供。


户外部署/锄地按world.SIZE动态边界检查，并保护牛棚、河流、桥、高山和祭台广场；grounds.nearby向会话提供可使用工作台。

## 分区与延迟时间

统一clock调用`elapse(seconds)`，仅累加领域时间、推进灶台并在阶段/成熟/干旱期限到达时结算；`settle()`、附近互动和导出确保农田状态及时。`advance(seconds)`保留为兼容确定性入口。land按render_region过滤绘制。grounds复用增量navigation，逻辑障碍包含停用的远区物件，确认布置仍核验碰撞及通路；空旷独立放置可提前返回。工作台配方交由mining处理。

## 独立田格

初始小农田5×3共15格，nearby按角色与田格中心距离选择最近格，land仅绘制网格和当前格金色边框。每格独立保存作物、生长和干旱计时。farm_grid.gd负责split旧矩形田及irrigation相连15格选择，规则由homestead调用；入口和HUD不计算农业规则。split保留每格土壤年龄/湿润状态，原作物和进度只保留第一格；已拆田格再次加载不复制。water在重置灌溉时钟前先结算生长。验证：tests/farm_cells_smoke.gd、crops_smoke.gd、water_smoke.gd。

森林内继续支持锄地和户外部署，grounds边界改用world.BOUNDS并向临时导航传入world.MIN，保护河桥与既有设施；农田尺寸、15格灌溉与返种子规则保持。

## 收获与肉类

每格成熟收获作物1、对应种子2；满包保留庄稼。猪、牛、羊肉共用灶台，每份60在线秒；E自动选择已有生肉，灶台旁B选中生肉使用可指定品种。成品留在灶台至领取，肉类和剩余时间持久化；旧烹饪队列按猪肉接续。所有生肉食用及熟肉恢复规则沿用猪肉。

## 魔法分支接入（0.8.0）

branch_runtime由magic模块注入，范围内非战斗旺炉将实际烹饪速度乘1.4；引水保持附近农田30秒湿润，仍使用原作物成熟／死亡／收获逻辑。
