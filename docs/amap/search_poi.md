# Search POI

> This document is mostly copied from the webpage: `https://lbs.amap.com/api/webservice/guide/api-advanced/search`.
>
> For more detailed information, visit the website.
>
> For querying adcode or city code, see [`docs/amap/adcode_citycode.csv`](adcode_citycode.csv).
>
> For querying poi categories encoding, see [`docs/amap/poi_categories_encoding.csv`](poi_categories_encoding.csv).
>
> For querying poi id (the unique identifier of a poi), use keyword search API and resolve the `pois.poi.id` field. See [`docs/amap/search_poi.md#searching-with-keyword`](search_poi.md#searching-with-keyword).

Caution! This documentation is truncated as some functions are not necessary in this project.

## Introduction

搜索服务 API 是一类简单的 HTTP 接口，提供多种查询 POI 信息的能力，其中包括关键字搜索、周边搜索、多边形搜索、ID 查询四种筛选机制。

目前搜索是不支持返回全量数据的，同请求参数翻页查询最多支持获取200条数据。

> 在此接口之中，您可以通过 city&citylimit 参数指定希望搜索的城市或区县。而 city 参数能够接收 citycode 和 adcode，citycode 仅能精确到城市，而 adcode 却能够精确到区县。
>
> 例如：北京，citycode：010，adcode：110000
>
> 北京-海淀区，citycode：010，adcode：110108
>
> 故使用 citycode 仅能在北京范围内搜索，而 adcode 能够指定在海淀区搜索。
>
> 综上所述，为了您查询的精确，我们强烈建议您使用 adcode。

For querying adcode or city code, see [`docs/amap/adcode_citycode.csv`](adcode_citycode.csv).

## When to Use

- 关键字搜索：通过用 POI 的关键字进行条件搜索，例如：肯德基、朝阳公园等；同时支持设置 POI 类型搜索，例如：银行
- 周边搜索：在用户传入经纬度坐标点附近，在设定的范围内，按照关键字或 POI 类型搜索；
- 多边形搜索：在多边形区域内进行搜索
- ID 查询：通过 POI ID，查询某个 POI 详情，建议可同输入提示 API 配合使用

## Searching with Keyword

### Searching with Keyword: Request

- URL: `https://restapi.amap.com/v3/place/text?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名     | 含义                     | 规则说明                                                                                                                                                                                                 | 是否必须                     | 缺省值       |
|------------|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------|--------------|
| key         | 请求服务权限标识         | 用户在高德地图官网申请Web服务API类型KEY                                                                                                                                                                  | 必填                         | 无           |
| keywords    | 查询关键字               | 规则：只支持一个关键字<br>若不指定city，并且搜索的为泛词（例如"美食"）的情况下，返回的内容为城市列表以及此城市内有多少结果符合要求。                                                                       | 必填（keyword或者types二选一必填） | 无           |
| types       | 查询POI类型              | 可选值：分类代码 或 汉字（若用汉字，请严格按照附件之中的汉字填写）<br>规则：多个关键字用"|"分割<br>分类代码由六位数字组成，一共分为三个部分，前两个数字代表大类；中间两个数字代表中类；最后两个数字代表小类。<br>例如：010000为汽车服务（大类）<br>010100为加油站（中类）<br>010101为中国石化（小类）<br>010900为汽车租赁（中类）<br>010901为汽车租赁还车（小类）<br>当指定010000，则010100等中类、010101等小类会被包含，当指定010900，则010901等小类会被包含。<br>注意：返回结果可能会包含中小类POI，但不保证包含所有，如需更精确的信息，推荐输入小类或缩小范围查询<br>下载POI分类编码和城市编码表<br>若不指定city，返回的内容为城市列表以及此城市内有多少结果符合要求。 | 必填（keyword或者types二选一必填） | 无           |
| city        | 查询城市                 | 可选值：城市中文、citycode、adcode<br>如：北京/010/110000<br>填入此参数后，会尽量优先返回此城市数据，但是不一定仅局限此城市结果，若仅需要某个城市数据请调用citylimit参数。<br>如：在深圳市搜天安门，返回北京天安门结果。 | 可选                         | 无（全国范围内搜索） |
| citylimit   | 仅返回指定城市数据       | 可选值：true/false                                                                                                                                                                                       | 可选                         | false        |
| children    | 是否按照层级展示子POI数据 | 可选值：children=1<br>当为0的时候，子POI都会显示。<br>当为1的时候，子POI会归类到父POI之中。<br>在extensions=all或者为空时生效                                                                              | 可选                         | 0            |
| offset      | 每页记录数据             | 强烈建议不超过25，若超过25可能造成访问报错                                                                                                                                                               | 可选                         | 20           |
| page        | 当前页数                 | 当前页数                                                                                                                                                                                                 | 可选                         | 1            |
| extensions  | 返回结果控制             | 此项默认返回基本地址信息；取值为all返回地址信息、附近POI、道路以及道路交叉口信息。                                                                                                                         | 可选                         | base         |
| sig         | 数字签名                 | 请参考 数字签名获取和使用方法                                                                                                                                                                             | 可选                         | 无           |
| callback    | 回调函数                 | callback值是用户定义的函数名称，此参数只在output=JSON时有效                                                                                                                                                 | 可选                         | 无           |

### Searching with Keywords: Example

```sh
https://restapi.amap.com/v3/place/text?keywords=西安钟楼&city=xian&offset=20&page=1&extensions=all&key=<YOUR_KEY>
```

Return value: See [`docs/amap/search_keyword.json`](search_keyword.json).

### Searching with Keyword: Return Explanation

| 名称          | 含义                     | 规则说明                                                                                     |
|---------------|--------------------------|----------------------------------------------------------------------------------------------|
| status        | 结果状态值，值为0或1     | 0: 请求失败；1: 请求成功                                                                     |
| info          | 返回状态说明             | status为0时，info返回错误原因，否则返回"OK"。详情参阅info状态表                              |
| count         | 搜索方案数目             |                                                                                              |
| suggestion    | 城市建议列表             | 当搜索的文本关键字在限定城市中没有返回时会返回建议城市列表；                                  |
| &nbsp;&nbsp;keywords | 关键字              |                                                                                              |
| &nbsp;&nbsp;cities   | 城市列表              |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;name | 名称          |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;num  | 该城市包含此关键字的个数 |                                                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;citycode | 该城市的citycode |                                                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;adcode | 该城市的adcode   |                                                                                        |
| pois          | 搜索POI信息列表          |                                                                                              |
| &nbsp;&nbsp;poi        | POI信息              |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;id | 唯一ID              |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;parent | 父POI的ID         | 当前POI如果有父POI，则返回父POI的ID。可能为空                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;name | 名称              |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;type | 兴趣点类型          | 顺序为大类、中类、小类<br>例如: 餐饮服务;中餐厅;特色地方风味餐厅                               |
| &nbsp;&nbsp;&nbsp;&nbsp;typecode | 兴趣点类型编码 | 例如: 050118                                                                                  |
| &nbsp;&nbsp;&nbsp;&nbsp;biz_type | 行业类型        |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;address | 地址             | 东四环中路189号百盛北门                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;location | 经纬度         | 格式: X,Y                                                                                    |
| &nbsp;&nbsp;&nbsp;&nbsp;distance | 离中心点距离     | 单位: 米；仅在周边搜索的时候有值返回                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;tel | POI的电话          |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;postcode | 邮编         | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;website | POI的网址       | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;email | POI的电子邮箱     | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;pcode | POI所在省份编码   | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;pname | POI所在省份名称   | 若是直辖市的时候，此处直接显示市名，例如北京市                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;citycode | 城市编码     | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;cityname | 城市名       | 若是直辖市的时候，此处直接显示市名，例如北京市                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;adcode | 区域编码       | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;adname | 区域名称       | 区县级别的返回，例如朝阳区                                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;entr_location | POI的入口经纬度 | extensions=all时返回，也可用作于POI的到达点；                                                  |
| &nbsp;&nbsp;&nbsp;&nbsp;exit_location | POI的出口经纬度 | 目前不会返回内容；                                                                            |
| &nbsp;&nbsp;&nbsp;&nbsp;navi_poiid | POI导航id     | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;gridcode | 地理格ID       | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;alias | 别名             | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;parking_type | 停车场类型 | 仅在停车场类型POI的时候显示该字段<br>展示停车场类型，包括：地下、地面、路边<br>extensions=all的时候显示 |
| &nbsp;&nbsp;&nbsp;&nbsp;tag | 该POI的特色内容 | 主要出现在美食类POI中，代表特色菜<br>例如"烤鱼,麻辣香锅,老干妈回锅肉"<br>extensions=all时返回    |
| &nbsp;&nbsp;&nbsp;&nbsp;indoor_map | 是否有室内地图标志 | 1，表示有室内相关数据<br>0，代表没有室内相关数据<br>extensions=all时返回                      |
| &nbsp;&nbsp;&nbsp;&nbsp;indoor_data | 室内地图相关数据 | 当indoor_map=0时，字段为空<br>extensions=all时返回                                            |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;cpid | 当前POI的父级POI | 如果当前POI为建筑物类POI，则cpid为自身POI ID；如果当前POI为商铺类POI，则cpid为其所在建筑物的POI ID |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;floor | 楼层索引     | 一般会用数字表示，例如8                                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;truefloor | 所在楼层 | 一般会带有字母，例如F8                                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;groupbuy_num | 团购数据     | 此字段逐渐废弃                                                                                |
| &nbsp;&nbsp;&nbsp;&nbsp;business_area | 所属商圈     | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;atag | 类目                 | 例如: 985大学/粤菜。现状仅ID查询返回                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;discount_num | 优惠信息数目 | 此字段逐渐废弃                                                                                |
| &nbsp;&nbsp;&nbsp;&nbsp;biz_ext | 深度信息       | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;rating | 评分         | 仅存在于餐饮、酒店、景点、影院类POI之下                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;cost | 人均消费       | 仅存在于餐饮、酒店、景点、影院类POI之下                                                        |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;meal_ordering | 是否可订餐 | 仅存在于餐饮相关POI之下（此字段逐渐废弃）                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;seat_ordering | 是否可选座 | 仅存在于影院相关POI之下（此字段逐渐废弃）                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ticket_ordering | 是否可订票 | 仅存在于景点相关POI之下（此字段逐渐废弃）                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;hotel_ordering | 是否可以订房 | 仅存在于酒店相关POI之下（此字段逐渐废弃）                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;photos | 照片相关信息     | extensions=all时返回                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;title | 图片介绍     |                                                                                              |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;url | 具体链接       |                                                                                              |

## Searching Around

### Searching Around: Request

- URL: `https://restapi.amap.com/v3/place/around?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名     | 含义               | 规则说明                                                                                                                                                                                                                                                                 | 是否必须 | 缺省值       |
|------------|--------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|--------------|
| key         | 请求服务权限标识   | 用户在高德地图官网申请Web服务API类型KEY                                                                                                                                                                                                                                  | 必填     | 无           |
| location    | 中心点坐标         | 规则：经度和纬度用","分隔，经度在前，纬度在后，经纬度小数点后不得超过6位                                                                                                                                                                                                | 必填     | 无           |
| keywords    | 查询关键字         | 规则：只支持一个关键字                                                                                                                                                                                                                                                   | 可选     | 无           |
| types       | 查询POI类型         | 多个类型用"|"分割；<br>可选值：分类代码 或 汉字（若用汉字，请严格按照附件之中的汉字填写）<br>分类代码由六位数字组成，一共分为三个部分，前两个数字代表大类；中间两个数字代表中类；最后两个数字代表小类。<br>若指定了某个大类，则所属的中类、小类都会被显示。<br>例如：010000为汽车服务（大类）<br>010100为加油站（中类）<br>010101为中国石化（小类）<br>010900为汽车租赁（中类）<br>010901为汽车租赁还车（小类）<br>当指定010000，则010100等中类、010101等小类会被包含，当指定010900，则010901等小类会被包含。<br>注意：返回结果可能会包含中小类POI，但不保证包含所有，如需更精确的信息，推荐输入小类或缩小范围查询<br>下载POI分类编码和城市编码表<br>当keywords和types均为空的时候，默认指定types为050000（餐饮服务）、070000（生活服务）、120000（商务住宅） | 可选     | 无           |
| city        | 查询城市           | 可选值：城市中文、中文全拼、citycode、adcode<br>如：北京/beijing/010/110000<br>当用户指定的经纬度和city出现冲突，若范围内有用户指定city的数据，则返回相关数据，否则返回为空。<br>如：经纬度指定石家庄，而city却指定天津，若搜索范围内有天津的数据则返回相关数据，否则返回为空。 | 可选     | 无（全国范围内搜索） |
| radius      | 查询半径           | 取值范围:0-50000。规则：大于50000按默认值，单位：米                                                                                                                                                                                                                       | 可选     | 5000         |
| sortrule    | 排序规则           | 规定返回结果的排序规则。<br>按距离排序：distance；综合排序：weight                                                                                                                                                                                                         | 可选     | distance     |
| offset      | 每页记录数据       | 强烈建议不超过25，若超过25可能造成访问报错                                                                                                                                                                                                                               | 可选     | 20           |
| page        | 当前页数           | 当前页数                                                                                                                                                                                                 | 可选     | 1            |
| extensions  | 返回结果控制       | 此项默认返回基本地址信息；取值为all返回地址信息、附近POI、道路以及道路交叉口信息。                                                                                                                                                                                         | 可选     | base         |
| sig         | 数字签名           | 请参考 数字签名获取和使用方法                                                                                                                                                                                                                                             | 可选     | 无           |
| callback    | 回调函数           | callback值是用户定义的函数名称，此参数只在output=JSON时有效                                                                                                                                                                                                                 | 可选     | 无           |

### Searching Around: Example

```sh
https://restapi.amap.com/v3/place/around?&location=108.94703,34.25943&radius=10000&types=110200&key=<YOUR_KEY>
```

Return value: See [`docs/amap/search_around.json`](search_around.json).

### Searching Around: Return Explanation

周边搜索搜索的响应结果的格式由请求参数 output 指定，返回结果见[Searching with Keyword](#searching-around-return-explanation).
