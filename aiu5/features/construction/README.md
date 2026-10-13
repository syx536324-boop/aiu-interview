# 自建房、施工与升级

catalog保留房屋／箭楼／云梯初始配方、96×80用地与防御；house_rules定义房屋等级、材料、耗时和晶石抗性。木／石／铁屋为1／2／3级，最高10级，新建房30在线秒才可进入。原村庄房屋、箭楼和云梯规则不变。

construction.start(session)、build(actor,bench,kind)支付原材料并消耗房屋建筑台，记录施工job。advance(delta)推进在线进度；target_job用于120像素内可见目标；finish_job完成已付材料的施工；progress_job推进总进度比例，boost_job暂时加速。木三／水三／火二只调用这些契约，不复制建设规则。

U由session转交production.open_upgrade；upgrade_snapshot提供等级、配方、选用晶石和进度；upgrade_near校验附近房屋、等级、状态、材料并原子支付。升到2级材料木50石50铁矿10，逐级各向上取整＋15%；耗时30×1.3^(目标等级－2)。目标4／6／8／10级预付自选属性晶石，完成后才加入crystals；每颗给建筑本体对应元素免伤2%，无屋内角色加成。升级中可继续使用原房，完成后刷新材质与等级生命。

hit(id,raw,consume_tool=false,element="")及skill_hit处理百分比建筑防御和对应元素抗性。房屋倒塌先撤出角色，保留房间／容器为可搜寻废墟。拆房仍消费已装备斧的耐久。施工／升级材料不退，提交失败完整回滚。

export_state／restore保存等级、crystals与job；旧房按kind推导原等级并保留生命，未离线施工。节点绘制等级、生命与施工进度，接口说明由后端提供。验证见branches_smoke.tscn、construction_smoke.gd、ladder_smoke.gd。
