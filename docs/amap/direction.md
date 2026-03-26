# Direction Planning

> This document is mostly copied from the webpage: `https://lbs.amap.com/api/webservice/guide/api/direction/`.
>
> For more detailed information, visit the website.
>
> For querying adcode or city code, see [`docs/amap/adcode_citycode.csv`](adcode_citycode.csv).
>
> For querying poi categories or poi code, see [`docs/amap/poi_code.csv`](poi_code.csv).

## Walking

步行路径规划 API 可以规划100km 以内的步行通勤方案，并且返回通勤方案的数据。最大支持 100km 的步行路线规划。

### Walking: Request

- URL: `https://restapi.amap.com/v3/direction/walking?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名        | 含义                 | 规则说明                                                                                     | 是否必须 | 缺省值 |
|---------------|----------------------|----------------------------------------------------------------------------------------------|----------|--------|
| key           | 请求服务权限标识     | 用户在高德地图官网申请Web服务API类型KEY                                                        | 必填     | 无     |
| origin        | 出发点               | 规则：lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位           | 必填     | 无     |
| destination   | 目的地               | 规则：lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位           | 必填     | 无     |
| origin_id     | 起点POI ID           | 起点为POI时，建议填充此值，可提升路线规划准确性                                               | 可选     | 无     |
| destination_id| 目的地POI ID         | 目的地为POI时，建议填充此值，可提升路线规划准确性                                             | 可选     | 无     |
| sig           | 数字签名             | 请参考数字签名获取和使用方法                                                                 | 可选     | 无     |
| output        | 返回数据格式类型     | 可选值：JSON，XML                                                                            | 可选     | JSON   |
| callback      | 回调函数             | callback值是用户定义的函数名称，此参数只在output=JSON时有效                                   | 可选     | 无     |

### Walking: Example

```sh
https://restapi.amap.com/v3/direction/walking?output=json&origin=108.983741,34.246233&destination=108.94703,34.25943&key=<YOUR_KEY>
```

Return value: See [`docs/amap/direction_walking.json`](direction_walking.json).

### Walking: Return Explanation

| 名称            | 含义                 | 规则说明                                                                 |
|-----------------|----------------------|--------------------------------------------------------------------------|
| status          | 返回状态             | 值为0或1<br>1：成功；0：失败                                              |
| info            | 返回的状态信息       | status为0时，info返回错误原；否则返回"OK"。详情参阅info状态表             |
| count           | 返回结果总数目       |                                                                          |
| route           | 路线信息列表         |                                                                          |
| &nbsp;&nbsp;origin       | 起点坐标             |                                                                          |
| &nbsp;&nbsp;destination  | 终点坐标             |                                                                          |
| &nbsp;&nbsp;paths        | 步行方案             |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;distance  | 起点和终点的步行距离 | 单位：米                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;duration  | 步行时间预计         | 单位：秒                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;steps     | 返回步行结果列表     |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;step   | 每段步行方案         |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;instruction | 路段步行指示       |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;road      | 道路名称           |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance  | 此路段距离         | 单位：米                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;orientation | 方向               |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;duration  | 此路段预计步行时间   |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;polyline  | 此路段坐标点       |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;action    | 步行主要动作       | 详情见 步行动作列表                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;assistant_action | 步行辅助动作   | 详情见 步行动作列表                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;walk_type | 这段路是否存在特殊的方式 | 0，普通道路<br>1，人行横道<br>3，地下通道<br>4，过街天桥<br>5，地铁通道<br>6，公园<br>7，广场<br>8，扶梯<br>9，直梯<br>10，索道<br>11，空中通道<br>12，建筑物穿越通道<br>13，行人通道<br>14，游船路线<br>15，观光车路线<br>16，滑道<br>18，扩路<br>19，道路附属连接线<br>20，阶梯<br>21，斜坡<br>22，桥<br>23，隧道<br>30，轮渡 |

步行动作列表：

| 主要动作列表       | 辅助动作列表       |
|--------------------|--------------------|
| 无基本导航动作     | 无辅助导航动作     |
| 左转               | 左转               |
| 右转               | 右转               |
| 向左前方           | 向左前方           |
| 向右前方           | 向右前方           |
| 向左后方           | 向左后方           |
| 向右后方           | 向右后方           |
| 直行               | 往后走             |
| 靠左               | 往前走             |
| 靠右               | 靠左               |
| 通过人行横道       | 靠右               |
| 通过过街天桥       | 通过人行横道       |
| 通过地下通道       | 通过过街天桥       |
| 通过广场           | 通过地下通道       |
| 到道路斜对面       | 通过广场           |
|                    | 到达目的地         |
|                    | 进入右侧道路       |
|                    | 进入左侧道路       |

## Transit

公交路径规划 API 可以规划综合各类公共（火车、公交、地铁）交通方式的通勤方案，并且返回通勤方案的数据。

### Transit: Request

- URL: `https://restapi.amap.com/v3/direction/transit/integrated?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名      | 含义                               | 规则说明                                                                                                   | 是否必须       | 缺省值 |
|-------------|------------------------------------|------------------------------------------------------------------------------------------------------------|----------------|--------|
| key         | 请求服务权限标识                   | 用户在高德地图官网申请Web服务API类型KEY                                                                     | 必填           | 无     |
| origin      | 出发点                             | 规则：lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位                         | 必填           | 无     |
| destination | 目的地                             | 规则：lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位                         | 必填           | 无     |
| city        | 城市/跨城规划时的起点城市           | 目前支持市内公交换乘/跨城公交的起点城市。可选值：城市名称/citycode                                          | 必填           | 无     |
| cityd       | 跨城公交规划时的终点城市           | 跨城公交规划必填参数。可选值：城市名称/citycode                                                             | 可选（跨城必填） | 无     |
| extensions  | 返回结果详略                       | 可选值：base(default)/all<br>base: 返回基本信息；all: 返回全部信息                                           | 可选           | base   |
| strategy    | 公交换乘策略                       | 可选值：<br>0: 最快捷模式；<br>1: 最经济模式；<br>2: 最少换乘模式；<br>3: 最少步行模式；<br>5: 不乘地铁模式 | 可选           | 0      |
| nightflag   | 是否计算夜班车                     | 可选值：<br>0: 不计算夜班车；<br>1: 计算夜班车                                                               | 可选           | 0      |
| date        | 出发日期                           | 根据出发时间和日期，筛选可乘坐的公交路线，格式示例：date=2014-3-19。在无需设置预计出发时间时，请不要在请求之中携带此参数。 | 可选           | 无     |
| time        | 出发时间                           | 根据出发时间和日期，筛选可乘坐的公交路线，格式示例：time=22:34。在无需设置预计出发时间时，请不要在请求之中携带此参数。 | 可选           | 无     |
| sig         | 数字签名                           | 请参考 数字签名获取和使用方法                                                                               | 可选           | 无     |
| output      | 返回数据格式类型                   | 可选值：JSON，XML                                                                                          | 可选           | JSON   |
| callback    | 回调函数                           | callback值是用户定义的函数名称，此参数只在output=JSON时有效                                                 | 可选           | 无     |

### Transit: Example

```sh
https://restapi.amap.com/v3/direction/transit/integrated?output=json&origin=108.983741,34.246233&destination=108.94703,34.25943&city=029&key=<YOUR_KEY>
```

Return value: See [`docs/amap/direction_transit.json`](direction_transit.json).

### Transit: Return Explanation

| 名称            | 含义                 | 规则说明                                                                 |
|-----------------|----------------------|--------------------------------------------------------------------------|
| status          | 返回状态             | 值为0或1<br>1：成功；0：失败                                              |
| info            | 返回的状态信息       | status为0时，info返回错误原；否则返回"OK"。详情参阅info状态表             |
| count           | 公交换乘方案数目     |                                                                          |
| route           | 公交换乘信息列表     |                                                                          |
| &nbsp;&nbsp;origin       | 起点坐标             |                                                                          |
| &nbsp;&nbsp;destination  | 终点坐标             |                                                                          |
| &nbsp;&nbsp;distance     | 起点和终点的步行距离 | 单位：米                                                                 |
| &nbsp;&nbsp;taxi_cost    | 出租车费用           | 单位：元                                                                 |
| &nbsp;&nbsp;transits     | 公交换乘方案列表     |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;transit   | 公交换乘方案         |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;cost   | 此换乘方案价格       | 单位：元                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;duration | 此换乘方案预期时间   | 单位：秒                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;nightflag | 是否是夜班车       | 0：非夜班车；1：夜班车                                                   |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;walking_distance | 此方案总步行距离   | 单位：米                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;emergency | 取值为all时返回     |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;linetype | 事件类型           | 1：影响乘坐；2：不影响乘坐                                                |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;eventTagDesc | 事件标签       | 值为："提示"、"甩站"、"突发"、"停运"                                      |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ldescription | 事件的线路上的文案  |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;busid  | 线路id               |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;busname | 线路名               |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;segments | 换乘路段列表         |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;walking | 此路段步行导航信息   | 详见 步行方案信息列表                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;bus    | 此路段公交导航信息   | 详见 公交方案信息列表                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;entrance | 地铁入口           | 只在地铁路段有值，详见 出入口信息列表                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;exit   | 地铁出口             | 只在地铁路段有值，详见 出入口信息列表                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;railway | 乘坐火车的信息       | 详情见只在地铁路段有值，详见 火车换乘信息列表                             |

#### 步行方案信息列表

| 名称              | 含义                 | 规则说明 |
|-------------------|----------------------|----------|
| origin            | 起点坐标             |          |
| destination       | 终点坐标             |          |
| distance          | 每段线路步行距离     | 单位：米 |
| duration          | 步行预计时间         | 单位：秒 |
| &nbsp;&nbsp;steps          | 步行路段列表         |          |
| &nbsp;&nbsp;&nbsp;&nbsp;instruction | 此段路的行走介绍     |          |
| &nbsp;&nbsp;&nbsp;&nbsp;road        | 路的名字             |          |
| &nbsp;&nbsp;&nbsp;&nbsp;distance    | 此段路的距离         |          |
| &nbsp;&nbsp;&nbsp;&nbsp;duration    | 此段路预计消耗时间   | 单位：秒 |
| &nbsp;&nbsp;&nbsp;&nbsp;polyline    | 此段路的坐标         |          |
| &nbsp;&nbsp;&nbsp;&nbsp;action      | 步行主要动作         |          |
| &nbsp;&nbsp;&nbsp;&nbsp;assistant_action | 步行辅助动作   |          |

#### 公交方案信息列表

| 名称              | 含义                     | 规则说明                                                                 |
|-------------------|--------------------------|--------------------------------------------------------------------------|
| buslines           | 步行路段列表             |                                                                          |
| &nbsp;&nbsp;departure_stop | 此段起乘站信息           | 格式如: 中关村                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;name         | 站点名字                 |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;id           | 站点 id                  |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;location     | 站点经纬度               |                                                                          |
| &nbsp;&nbsp;arrival_stop   | 此段下车站               | 格式如: 中关村                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;name         | 站点名字                 |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;id           | 站点 id                  |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;location     | 站点经纬度               |                                                                          |
| &nbsp;&nbsp;name            | 公交路线名称             | 格式如: 445路(南十里居--地铁望京西站)                                    |
| &nbsp;&nbsp;id              | 公交路线 id              |                                                                          |
| &nbsp;&nbsp;type            | 公交类型                 | 格式如: 地铁线路                                                         |
| &nbsp;&nbsp;distance        | 公交行驶距离             | 单位: 米                                                                 |
| &nbsp;&nbsp;duration        | 公交预计行驶时间         | 单位: 秒                                                                 |
| &nbsp;&nbsp;polyline        | 此路段坐标集             | 格式为坐标串，如: 116.481247,39.990704;116.481270,39.990726              |
| &nbsp;&nbsp;start_time      | 首班车时间               | 格式如: 0600，代表06: 00                                                 |
| &nbsp;&nbsp;end_time        | 末班车时间               | 格式如: 2300，代表23: 00                                                 |
| &nbsp;&nbsp;station_start_time | 上车站点首班时间       | 格式如: 0600，代表06: 00                                                 |
| &nbsp;&nbsp;station_end_time   | 上车站点末班时间       | 格式如: 2300，代表23: 00                                                 |
| &nbsp;&nbsp;via_num         | 此段途经公交站数         |                                                                          |
| &nbsp;&nbsp;via_stops       | 此段途经公交站点列表     |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;name         | 途径公交站点信息         |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;id           | 公交站点编号             |                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;location     | 公交站点经纬度           |                                                                          |

#### 出入口信息列表

| 名称     | 含义       |
|----------|------------|
| name     | 入口名称   |
| location | 入口经纬度 |

#### 火车换乘信息列表

| 名称           | 含义                               | 规则说明                                                                 |
|----------------|------------------------------------|--------------------------------------------------------------------------|
| id             | 线路 id 编号                       |                                                                          |
| time           | 该线路路段耗时                     |                                                                          |
| name           | 线路名称                           |                                                                          |
| trip           | 线路车次号                         |                                                                          |
| distance       | 该 item 换乘段的行车总距离          |                                                                          |
| type           | 线路车次类型                       |                                                                          |
| departure_stop | 火车始发站信息                     |                                                                          |
| &nbsp;&nbsp;id          | 上车站点 ID                        |                                                                          |
| &nbsp;&nbsp;name        | 上车站点名称                       |                                                                          |
| &nbsp;&nbsp;location    | 上车站点经纬度                     |                                                                          |
| &nbsp;&nbsp;adcode      | 上车站点所在城市的 adcode           |                                                                          |
| &nbsp;&nbsp;time        | 上车点发车时间                     |                                                                          |
| &nbsp;&nbsp;start       | 是否始发站，1表示为始发站，0表示非始发站 |                                                                          |
| arrival_stop   | 火车到站信息                       |                                                                          |
| &nbsp;&nbsp;id          | 下车站点 ID                        |                                                                          |
| &nbsp;&nbsp;name        | 下车站点名称                       |                                                                          |
| &nbsp;&nbsp;location    | 下车站点经纬度                     |                                                                          |
| &nbsp;&nbsp;adcode      | 下车站点所在城市的 adcode           |                                                                          |
| &nbsp;&nbsp;time        | 到站时间，如大于24:00，则表示跨天   |                                                                          |
| &nbsp;&nbsp;end         | 是否为终点站，1表示为终点站，0表示非终点站 |                                                                          |
| via_stop       | 途径站点信息，extensions=all时返回 |                                                                          |
| &nbsp;&nbsp;name        | 途径站点的名称                     |                                                                          |
| &nbsp;&nbsp;id          | 途径站点的 ID                      |                                                                          |
| &nbsp;&nbsp;location    | 途径站点的坐标点                   |                                                                          |
| &nbsp;&nbsp;time        | 途径站点的进站时间，如大于24:00,则表示跨天 |                                                                          |
| &nbsp;&nbsp;wait        | 途径站点的停靠时间，单位：分钟      |                                                                          |
| alters         | 聚合的备选方案，extensions=all时返回 |                                                                          |
| &nbsp;&nbsp;id          | 备选方案 ID                        |                                                                          |
| &nbsp;&nbsp;name        | 备选线路名称                       |                                                                          |
| spaces         | 仓位及价格信息                     |                                                                          |
| &nbsp;&nbsp;code        | 仓位编码                           |                                                                          |
| &nbsp;&nbsp;cost        | 仓位费用                           |                                                                          |

#### 火车路线类型表

| 线路类型代码 | 公共交通工具备注       | 线路类型代码 | 公共交通工具备注       |
|--------------|------------------------|--------------|------------------------|
| 2010         | 普客火车               | 2015         | T字头的特快火车        |
| 2011         | G字头的高铁火车        | 2016         | K字头的快车火车        |
| 2012         | D字头的动车火车        | 2017         | L字头，Y字头的临时火车 |
| 2013         | C字头的城际火车        | 2018         | S字头的郊区线火车      |
| 2014         | Z字头的直达特快火车    |              |                        |

#### 仓位级别表

| 仓位级别 | 仓位备注             | 仓位级别 | 仓位备注             |
|----------|----------------------|----------|----------------------|
| 0        | 不分仓位级别         | 20       | 火车高级软卧下铺     |
| 9        | 特等座               | 21       | 火车商务座           |
| 10       | 火车硬座             | 22       | 长途汽车座席         |
| 11       | 火车软座             | 23       | 长途汽车卧席上铺     |
| 12       | 火车软座1等座        | 24       | 长途汽车卧席中铺     |
| 13       | 火车软座2等座        | 25       | 长途汽车卧席下铺     |
| 14       | 火车硬卧上铺         | 30       | 飞机经济舱           |
| 15       | 火车硬卧中铺         | 31       | 飞机商务舱           |
| 16       | 火车硬卧下铺         | 40       | 客轮经济舱           |
| 17       | 火车软卧上铺         | 41       | 客轮3等舱            |
| 18       | 火车软卧下铺         | 42       | 客轮2等舱            |
| 19       | 火车高级软卧上铺     | 43       | 客轮豪华舱           |

## Driving

驾车路径规划 API 可以规划以小客车、轿车通勤出行的方案，并且返回通勤方案的数据。

### Driving: Request

- URL: `https://restapi.amap.com/v3/direction/driving?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名称 | 含义 | 规则说明 | 是否必须 | 缺省值 |
| --- | --- | --- | --- | --- |
| key | 用户唯一标识 | 用户在高德地图官网申请 | 是 | 无 |
| origin | 出发点 | 经度在前，纬度在后，经度和纬度用","分割，经纬度小数点后不得超过6位。格式为x1,y1|x2,y2|x3,y3。<br>由于在实际使用过程中，存在定位飘点的情况。为了解决此类问题，允许传入多个起点用于计算车头角度。<br>最多允许传入3个坐标对，每对坐标之间距离必须超过2m。虽然对每对坐标之间长度没有上限，但是如果超过4米会有概率性出现不准确的情况。使用三个点来判断距离和角度的有效性，如果两者都有效，使用第一个点和最后一个点计算的角度设置抓路的角度，规划路径时以最后一个坐标对进行规划。 | 是 | 无 |
| destination | 目的地 | 经度在前，纬度在后，经度和纬度用","分割，经纬度小数点后不得超过6位。 | 是 | 无 |
| originid | 出发点 poiid | 起点为 POI 时，建议填充此值，可提升路线规划准确性 | 否 | 无 |
| destinationid | 目的地 poiid | 当终点为 POI 时，建议填充此值 | 否 | 无 |
| destinationtype | 终点的 poi 类别 | 当用户知道终点 POI 的类别时候，建议填充此值 | 否 | 无 |
| strategy | 驾车选择策略 | 下方10~20的策略，会返回多条路径规划结果。（高德地图 APP 策略也包含在内，强烈建议从此策略之中选择）<br>下方策略 0~9的策略，仅会返回一条路径规划结果。<br>下方策略返回多条路径规划结果<br>10，返回结果会躲避拥堵，路程较短，尽量缩短时间，与高德地图的默认策略也就是不进行任何勾选一致<br>11，返回三个结果包含：时间最短；距离最短；躲避拥堵 （由于有更优秀的算法，建议用10代替）<br>12，返回的结果考虑路况，尽量躲避拥堵而规划路径，与高德地图的“躲避拥堵”策略一致<br>13，返回的结果不走高速，与高德地图“不走高速”策略一致<br>14，返回的结果尽可能规划收费较低甚至免费的路径，与高德地图“避免收费”策略一致<br>15，返回的结果考虑路况，尽量躲避拥堵而规划路径，并且不走高速，与高德地图的“躲避拥堵&不走高速”策略一致<br>16，返回的结果尽量不走高速，并且尽量规划收费较低甚至免费的路径结果，与高德地图的“避免收费&不走高速”策略一致<br>17，返回路径规划结果会尽量的躲避拥堵，并且规划收费较低甚至免费的路径结果，与高德地图的“躲避拥堵&避免收费”策略一致<br>18，返回的结果尽量躲避拥堵，规划收费较低甚至免费的路径结果，并且尽量不走高速路，与高德地图的“避免拥堵&避免收费&不走高速”策略一致<br>19，返回的结果会优先选择高速路，与高德地图的“高速优先”策略一致<br>20，返回的结果会优先考虑高速路，并且会考虑路况躲避拥堵，与高德地图的“躲避拥堵&高速优先”策略一致<br>下方策略仅返回一条路径规划结果<br>0，速度优先，此路线不一定距离最短<br>1，费用优先，不走收费路段，且耗时最少的路线<br>2，常规最快，综合距离/耗时规划结果<br>3，速度优先，不走快速路，例如京通快速路（因为策略迭代，建议使用13）<br>4，躲避拥堵，但是可能会存在绕路的情况，耗时可能较长<br>5，多策略（同时使用速度优先、费用优先、距离优先三个策略计算路径）。<br>其中必须说明，就算使用三个策略算路，会根据路况不固定的返回一~三条路径规划信息。<br>6，速度优先，不走高速，但是不排除走其余收费路段<br>7，费用优先，不走高速且避免所有收费路段<br>8，躲避拥堵和收费，可能存在走高速的情况，并且考虑路况不走拥堵路线，但有可能存在绕路和时间较长<br>9，躲避拥堵和收费，不走高速 | 否 | 0 |
| waypoints | 途经点 | 经度和纬度","分割，经度在前，纬度在后，小数点后不超过6位，坐标点之间用";"分隔<br>最大数目：16个坐标点。如果输入多个途经点，则按照用户输入的顺序进行路径规划 | 否 | 无 |
| avoidpolygons | 避让区域 | 区域避让，支持32个避让区域，每个区域最多可有16个顶点<br>经度和纬度用","分割，经度在前，纬度在后，小数点后不超过6位，坐标点之间用";"分隔，区域之间用"|"分隔。如果是四边形则有四个坐标点，如果是五边形则有五个坐标点；<br>避让区域不能超过81平方公里，否则避让区域会失效。 | 否 | 无 |
| province | 用汉字填入车牌省份缩写，用于判断是否限行 | 例如：京 | 否 | 无 |
| number | 填入除省份及标点之外，车牌的字母和数字（需大写）。用于判断限行相关。 | 例如:NH1N11<br>支持6位传统车牌和7位新能源车牌 | 否 | 无 |
| cartype | 车辆类型 | 0：普通汽车(默认值) 1: 纯电动车 2: 插电混动车 | 否 | 0 |
| ferry | 在路径规划中，是否使用渡轮 | 0:使用渡轮(默认) 1:不使用渡轮 | 否 | 0 |
| roadaggregation | 是否返回路径聚合信息 | false:不返回路径聚合信息<br>true:返回路径聚合信息，在 steps 上层增加 roads 做聚合 | 否 | false |
| nosteps | 是否返回 steps 字段内容 | 当取值为0时，steps 字段内容正常返回；<br>当取值为1时，steps 字段内容为空； | 否 | 0 |
| sig | 数字签名 | 请参考 数字签名获取和使用方法，数字签名认证用户必填 | 否 | 无 |
| output | 返回数据格式类型 | 可选值：JSON，XML | 否 | JSON |
| callback | 回调函数 | callback 值是用户定义的函数名称，此参数只在 output=JSON 时有效 | 否 | 无 |
| extensions | 返回结果控制 | 可选值：base/all<br>base:返回基本信息；all: 返回全部信息 | 是 | base |

### Driving: Example

```sh
https://restapi.amap.com/v3/direction/driving?output=json&extensions=all&origin=108.983741,34.246233&destination=108.94703,34.25943&key=<YOUR_KEY>
```

Return value: See [`docs/amap/direction_driving.json`](direction_driving.json).

### Driving: Return Explanation

| 名称 | 含义 | 规则说明 |
| --- | --- | --- |
| status | 结果状态值，值为0或1 | 0：请求失败；1：请求成功 |
| info | 返回状态说明 | status 为0时，info 返回错误原因，否则返回“OK”。详情参阅 info 状态表 |
| count | 驾车路径规划方案数目 | |
| route | 驾车路径规划信息列表 | |
| &nbsp;&nbsp;origin | 起点坐标 | 规则： lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位 |
| &nbsp;&nbsp;destination | 终点坐标 | 规则： lon, lat（经度，纬度），","分割，如117.500244, 40.417801 经纬度小数点不超过6位 |
| &nbsp;&nbsp;taxi_cost | 打车费用 | 单位：元，注意：extensions=all 时才会返回 |
| &nbsp;&nbsp;paths | 驾车换乘方案 | |
| &nbsp;&nbsp;&nbsp;&nbsp;path | 驾车换乘方案 | |
| &nbsp;&nbsp;&nbsp;&nbsp;distance | 行驶距离 | 单位：米 |
| &nbsp;&nbsp;&nbsp;&nbsp;duration | 预计行驶时间 | 单位：秒 |
| &nbsp;&nbsp;&nbsp;&nbsp;strategy | 导航策略 | |
| &nbsp;&nbsp;&nbsp;&nbsp;tolls | 此导航方案道路收费 | 单位：元 |
| &nbsp;&nbsp;&nbsp;&nbsp;restriction | 限行结果 | 0 代表限行已规避或未限行，即该路线没有限行路段<br>1 代表限行无法规避，即该线路有限行路段 |
| &nbsp;&nbsp;&nbsp;&nbsp;traffic_lights | 红绿灯个数 | |
| &nbsp;&nbsp;&nbsp;&nbsp;toll_distance | 收费路段距离 | |
| &nbsp;&nbsp;&nbsp;&nbsp;steps | 导航路段 | |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;step | 导航路段 | 详情见 导航路段信息 step 列表 |

#### 导航路段信息step列表

| 名称 | 含义 | 规则说明 |
| --- | --- | --- |
| instruction | 行驶指示 | |
| orientation | 方向 | |
| road | 道路名称 | |
| distance | 此路段距离 | 单位：米 |
| tolls | 此段收费 | 单位：元 |
| toll_distance | 收费路段距离 | 单位：米 |
| toll_road | 主要收费道路 | |
| polyline | 此路段坐标点串 | 格式为坐标串，如：116.481247,39.990704;116.481270,39.990726 |
| action | 导航主要动作 | 详见 驾车动作列表 |
| assistant_action | 导航辅助动作 | 详见 驾车动作列表 |
| tmcs | 驾车导航详细信息 | 其中包含 tmc 对象 |
| &nbsp;&nbsp;distance | 此段路的长度 | 单位：米 |
| &nbsp;&nbsp;status | 此段路的交通情况 | 未知、畅通、缓行、拥堵、严重拥堵 |
| &nbsp;&nbsp;polyline | 此段路的轨迹 | 规格：x1,y1;x2,y2 |
| cities | 路线途经行政区划 | |
| &nbsp;&nbsp;name | 名称 | |
| &nbsp;&nbsp;citycode | 途径城市编码 | |
| &nbsp;&nbsp;adcode | 途径区域编码 | |
| &nbsp;&nbsp;districts | | |
| &nbsp;&nbsp;&nbsp;&nbsp;name | 途径区县名称 | |
| &nbsp;&nbsp;&nbsp;&nbsp;adcode | 途径区县 adcode | |

#### 驾车动作列表

> 仅在extensions=all 时以下信息才会返回。

主要动作列表：

```
无基本导航动作
左转
右转
向左前方行驶
向右前方行驶
向左后方行驶
向右后方行驶
左转调头
直行
靠左
靠右
进入环岛
离开环岛
减速行驶
```

辅助动作列表：

```
无辅助导航动作
进入主路
进入辅路
进入高速
进入匝道
进入隧道
进入中间岔道
进入右岔路
进入左岔路
进入右转专用道
进入左转专用道
进入中间道路
进入右侧道路
进入左侧道路
靠右行驶进入辅路
靠左行驶进入辅路
靠右行驶进入主路
靠左行驶进入主路
靠右行驶进入右转专用道
进入轮渡
驶离轮渡
沿当前道路行驶
沿辅路行驶
沿主路行驶
到达出口
到达服务区
到达收费站
到达途经地
到达目的地的
绕环岛左转
绕环岛右转
绕环岛直行
绕环岛调头
小环岛不数出口
到达复杂路口，走右边第一出口
到达复杂路口，走右边第二出口
到达复杂路口，走右边第三出口
到达复杂路口，走右边第四出口
到达复杂路口，走右边第五出口
到达复杂路口，走左边第一出口
到达复杂路口，走左边第二出口
到达复杂路口，走左边第三出口
到达复杂路口，走左边第四出口
到达复杂路口，走左边第五出口
进入调头专用路
```

## Cycling

骑行路径规划用于规划骑行通勤方案，规划时会考虑天桥、单行线、封路等情况。最大支持 500km 的骑行路线规划。

### Cycling: Request

- URL: `https://restapi.amap.com/v4/direction/bicycling?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名 | 含义 | 规则说明 | 是否必填 | 缺省值 |
| --- | --- | --- | --- | --- |
| key | 请求服务权限标识 | 用户在高德地图官网 申请 Web 服务 API 类型 KEY | 是 | 无 |
| origin | 出发点经纬度 | 填入规则：X,Y，采用","分隔，例如 "117.500244, 40.417801" <br> 小数点后不得超过6位 | 是 | 无 |
| destination | 目的地经纬度 | 填入规则：X,Y，采用","分隔，例如 "117.500244, 40.417801" <br> 小数点后不得超过6位 | 是 | 无 |

### Cycling: Example

```sh
https://restapi.amap.com/v4/direction/bicycling?output=json&origin=108.983741,34.246233&destination=108.94703,34.25943&key=<YOUR_KEY>
```

Return value: See [`docs/amap/direction_cycling.json`](direction_cycling.json).

### Cycling: Return Explanation

| 名称 | 类型 | 含义 | 规则说明 |
| --- | --- | --- | --- |
| data | 对象 | 里面包含具体内容 | 业务数据字段 |
| &nbsp;&nbsp;origin | String | 起点坐标 | 格式:X,Y |
| &nbsp;&nbsp;destination | String | 终点坐标 | 格式:X,Y |
| &nbsp;&nbsp;paths | 数组 | 骑行方案列表信息 | |
| &nbsp;&nbsp;&nbsp;&nbsp;distance | 数值 | 起终点的骑行距离 | 单位：米 |
| &nbsp;&nbsp;&nbsp;&nbsp;duration | 数值 | 起终点的骑行时间 | 单位：秒 |
| &nbsp;&nbsp;&nbsp;&nbsp;steps | 数组 | 具体骑行结果 | |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;instruction | String | 路段骑行指示 | 例如："骑行54米右转" |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;road | String | 此段路道路名称 | 有可能出现空，需要特别指出，日后会用null表示<br>例如："建国门北大街" |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 数值 | 此段路骑行距离 | |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;orientation | String | 此段路骑行方向 | 例如："南" |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;duration | 数值 | 此段路骑行耗时 | 单位：秒 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;polyline | String | 此段路骑行的坐标点 | 格式：X,Y;X1,Y1;X2,Y2 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;action | String | 此段路骑行主要动作 | 内容为中文指示。<br>骑行-主要动作，可能为空，也可能为左转、右转、向左前方行驶、向右前方行驶等 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;assistant_action | String | 此段路骑行辅助动作 | 内容为中文提示。<br>例如："到达目的地" |
| errcode | 数值 | 返回结果码 | 0，表示成功 |
| errdetail | String | 具体错误原因 | 此字段会详细说明错误原因 |
| errmsg | String | 返回状态说明 | OK代表成功 |

## Distance Measurement

### Distance Measurement: Request

- URL: `https://restapi.amap.com/v3/distance?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名 | 含义 | 规则说明 | 是否必须 | 缺省值 |
| --- | --- | --- | --- | --- |
| key | 请求服务权限标识 | 用户在高德地图官网 申请 Web 服务 API 类型 KEY | 必填 | 无 |
| origins | 出发点 | 支持100个坐标对，坐标对用"|"分隔；经度和纬度用","分隔 | 必填 | 无 |
| destination | 目的地 | 规则： lon, lat（经度，纬度），“,”分割<br>如117.500244, 40.417801 经纬度小数点不超过6位 | 必填 | 无 |
| type | 路径计算的方式和方法 | 0：直线距离<br>1：驾车导航距离（仅支持国内坐标）。<br>必须指出，当为1时会考虑路况，故在不同时间请求返回结果可能不同。<br>此策略和驾车路径规划接口的 strategy=4策略基本一致，策略为“躲避拥堵的路线，但是可能会存在绕路的情况，耗时可能较长”<br>若需要实现高德地图客户端效果，可以考虑使用驾车路径规划接口<br>3：步行规划距离（仅支持5km之间的距离） | 可选 | 1 |
| sig | 数字签名 | 请参考 数字签名获取和使用方法 | 可选 | 无 |
| output | 返回数据格式类型 | 可选值：JSON，XML | 可选 | JSON |
| callback | 回调函数 | callback 值是用户定义的函数名称，此参数只在 output=JSON 时有效 | 可选 | 无 |

### Distance Measurement: Example

```sh
https://restapi.amap.com/v3/distance?type=1&origins=108.983741,34.246233&destination`=108.94703,34.25943&key=<YOUR_KEY>
```

Return value: See [`docs/amap/direction_measurement.json`](direction_measurement.json).

### Distance Measurement: Return Explanation

| 名称 | 说明 |
| --- | --- |
| status | 返回结果状态值，值为0或1，0表示请求失败；1表示请求成功 |
| info | 返回状态说明，status 为0时，info 返回错误原因；否则返回“OK”。详情参阅 info 状态表 |
| results | 距离信息列表 |
| &nbsp;&nbsp;result | 距离信息 |
| &nbsp;&nbsp;&nbsp;&nbsp;origin_id | 起点坐标，起点坐标序列号（从 1 开始） |
| &nbsp;&nbsp;&nbsp;&nbsp;dest_id | 终点坐标，终点坐标序列号（从 1 开始） |
| &nbsp;&nbsp;&nbsp;&nbsp;distance | 路径距离，单位：米 |
| &nbsp;&nbsp;&nbsp;&nbsp;duration | 预计行驶时间，单位：秒 |
| &nbsp;&nbsp;&nbsp;&nbsp;info | 仅在出错的时候显示该字段。大部分显示“未知错误”<br>由于此接口支持批量请求，建议不论批量与否用此字段判断请求是否成功 |
| &nbsp;&nbsp;&nbsp;&nbsp;code | 仅在出错的时候显示此字段。<br>在驾车模式下：<br>1，指定地点之间没有可以行车的道路<br>2，起点/终点 距离所有道路均距离过远（例如在海洋/矿业）<br>3，起点/终点不在中国境内 |