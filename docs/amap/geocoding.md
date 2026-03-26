# Geocoding and Reverse Geocoding

> This document is mostly copied from the webpage: `https://lbs.amap.com/api/webservice/guide/api/direction/`.
>
> For more detailed information, visit the website.
>
> For querying adcode or city code, see [`docs/amap/adcode_citycode.csv`](adcode_citycode.csv).
>
> For querying poi categories encoding, see [`docs/amap/poi_categories_encoding.csv`](poi_categories_encoding.csv).
>
> For querying poi id (the unique identifier of a poi), use keyword search API and resolve the `pois.poi.id` field. See [`docs/amap/search_poi.md#searching-with-keyword`](search_poi.md#searching-with-keyword).

## Geocoding

### Geocoding: Request

- URL: `https://restapi.amap.com/v3/geocode/geo?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名   | 含义               | 规则说明                                                                                                       | 是否必须 | 缺省值                 |
| -------- | ------------------ | ---------------------------------------------------------------------------------------------------------------- | -------- | ---------------------- |
| key      | 高德Key            | 用户在高德地图官网申请 Web 服务 API 类型 Key                                                                      | 必填     | 无                     |
| address  | 结构化地址信息     | 规则遵循：国家、省份、城市、区县、城镇、乡村、街道、门牌号码、屋邨、大厦，如：北京市朝阳区阜通东大街6号。           | 必填     | 无                     |
| city     | 指定查询的城市     | 可选输入内容包括：指定城市的中文（如北京）、指定城市的中文全拼（beijing）、citycode（010）、adcode（110000），不支持县级市。当指定城市查询内容为空时，会进行全国范围内的地址转换检索。adcode 信息可参考城市编码表获取 | 可选     | 无，会进行全国范围内搜索 |
| sig      | 数字签名           | 请参考数字签名获取和使用方法                                                                                     | 可选     | 无                     |
| output   | 返回数据格式类型   | 可选输入内容包括：JSON，XML。设置 JSON 返回结果数据将会以 JSON 结构构成；如果设置 XML 返回结果数据将以 XML 结构构成。 | 可选     | JSON                   |
| callback | 回调函数           | callback 值是用户定义的函数名称，此参数只在 output 参数设置为 JSON 时有效。                                       | 可选     | 无                     |

### Geocoding: Example

```sh
https://restapi.amap.com/v3/geocode/geo?output=json&address=陕西省西安市新城区西安钟楼&key=<YOUR_KEY>
```

Return value: See [`docs/amap/geocoding.json`](geocoding.json).

### Geocoding: Return Explanation

| 名称      | 含义               | 规则说明                                                                                     |
| --------- | ------------------ | -------------------------------------------------------------------------------------------- |
| status    | 返回结果状态值     | 返回值为 0 或 1，0 表示请求失败；1 表示请求成功。                                             |
| count     | 返回结果数目       | 返回结果的个数。                                                                             |
| info      | 返回状态说明       | 当 status 为 0 时，info 会返回具体错误原因，否则返回“OK”。详情可以参阅 info 状态表            |
| geocodes  | 地理编码信息列表   | 结果对象列表，包括下述字段:                                                                 |
| &nbsp;&nbsp;country | 国家               | 国内地址默认返回中国                                                                         |
| &nbsp;&nbsp;province | 地址所在的省份名   | 例如：北京市。此处需要注意的是，中国的四大直辖市也算作省级单位。                               |
| &nbsp;&nbsp;city | 地址所在的城市名   | 例如：北京市                                                                                 |
| &nbsp;&nbsp;citycode | 城市编码           | 例如：010                                                                                    |
| &nbsp;&nbsp;district | 地址所在的区       | 例如：朝阳区                                                                                 |
| &nbsp;&nbsp;street | 街道               | 例如：阜通东大街                                                                             |
| &nbsp;&nbsp;number | 门牌               | 例如：6号                                                                                    |
| &nbsp;&nbsp;adcode | 区域编码           | 例如：110101                                                                                 |
| &nbsp;&nbsp;location | 坐标点             | 经度，纬度                                                                                   |
| &nbsp;&nbsp;level | 匹配级别           | 参见下方的地理编码匹配级别列表                                                               |

注意，部分返回值当返回值存在时，将以字符串类型返回；当返回值不存在时，则以数组类型返回。

## Reverse Geocoding

### Reverse Geocoding: Request

- URL: `https://restapi.amap.com/v3/geocode/regeo?parameters`
- 请求方式：GET

`parameters` 代表的参数包括必填参数和可选参数。所有参数均使用和号字符(&)进行分隔。下面的列表枚举了这些参数及其使用规则。

| 参数名     | 含义                 | 规则说明                                                                                                                                                                                                 | 是否必须 | 缺省值 |
| ---------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------ |
| key        | 高德Key              | 用户在高德地图官网申请 Web 服务 API 类型 Key                                                                                                                                                             | 必填     | 无     |
| location   | 经纬度坐标           | 传入内容规则：经度在前，纬度在后，经纬度间以“,”分割，经纬度小数点后不要超过 6 位                                                                                                                         | 必填     | 无     |
| poitype    | 返回附近 POI 类型    | 以下内容需要 extensions 参数为 all 时才生效。逆地理编码在进行坐标解析之后不仅可以返回地址描述，也可以返回经纬度附近符合限定要求的 POI 内容（在 extensions 字段值为 all 时才会返回 POI 内容）。设置 POI 类型参数相当于为上述操作限定要求。参数仅支持传入 POI TYPECODE，可以传入多个 POI TYPECODE，相互之间用“|”分隔。获取 POI TYPECODE 可以参考 POI 分类表 | 可选     | 无     |
| radius     | 搜索半径             | radius 取值范围：0~3000，默认值：1000。单位：米                                                                                                                                                         | 可选     | 1000   |
| extensions | 返回结果控制         | extensions 参数默认取值是 base，也就是返回基本地址信息；extensions 参数取值为 all 时会返回基本地址信息、附近 POI 内容、道路信息以及道路交叉口信息。                                                         | 可选     | base   |
| roadlevel  | 道路等级             | 以下内容需要 extensions 参数为 all 时才生效。可选值：0，1 当 roadlevel=0时，显示所有道路 ； 当 roadlevel=1时，过滤非主干道路，仅输出主干道路数据                                                         | 可选     | 无     |
| sig        | 数字签名             | 请参考 数字签名获取和使用方法                                                                                                                                                                             | 可选     | 无     |
| output     | 返回数据格式类型     | 可选输入内容包括：JSON，XML。设置 JSON 返回结果数据将会以 JSON 结构构成；如果设置 XML 返回结果数据将以 XML 结构构成。                                                                                     | 可选     | JSON   |
| callback   | 回调函数             | callback 值是用户定义的函数名称，此参数只在 output 参数设置为 JSON 时有效。                                                                                                                               | 可选     | 无     |
| homecorpor | 是否优化 POI 返回顺序 | 以下内容需要 extensions 参数为 all 时才生效。homecorpor 参数的设置可以影响召回 POI 内容的排序策略，目前提供三个可选参数：0：不对召回的排序策略进行干扰。1：综合大数据分析将居家相关的 POI 内容优先返回，即优化返回结果中 pois 字段的poi 顺序。2：综合大数据分析将公司相关的 POI 内容优先返回，即优化返回结果中 pois 字段的poi 顺序。 | 可选     | 0      |

### Reverse Geocoding: Example

```sh
https://restapi.amap.com/v3/geocode/regeo?output=json&location=108.94703,34.25943&radius=1000&extensions=all&key=<YOUR_KEY>
```

Return value: See [`docs/amap/geocoding_reverse.json`](geocoding_reverse.json).

### Reverse Geocoding: Return Explanation

| 名称                | 含义                     | 规则说明                                                                                                                                 |
| ------------------- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| status              | 返回结果状态值           | 返回值为 0 或 1，0 表示请求失败；1 表示请求成功。                                                                                        |
| info                | 返回状态说明             | 当 status 为 0 时，info 会返回具体错误原因，否则返回“OK”。详情可以参考 info 状态表                                                         |
| regeocode           | 逆地理编码列表           | 返回 regeocode 对象；regeocode 对象包含的数据如下:                                                                                        |
| &nbsp;&nbsp;addressComponent | 地址元素列表         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;country | 坐标点所在国家名称 | 例如：中国                                                                                                                               |
| &nbsp;&nbsp;&nbsp;&nbsp;province | 坐标点所在省名称   | 例如：北京市                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;city | 坐标点所在城市名称     | 请注意：当城市是省直辖县时返回为空，以及城市为北京、上海、天津、重庆四个直辖市时，该字段返回为空；省直辖县列表                             |
| &nbsp;&nbsp;&nbsp;&nbsp;citycode | 城市编码           | 例如：010                                                                                                                                |
| &nbsp;&nbsp;&nbsp;&nbsp;district | 坐标点所在区       | 例如：海淀区                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;adcode | 行政区编码           | 例如：110108                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;township | 坐标点所在乡镇/街道（此街道为社区街道，不是道路信息） | 例如：燕园街道                                                                                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;towncode | 乡镇街道编码       | 例如：110101001000                                                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;neighborhood | 社区信息列表     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | 社区名称         | 例如：北京大学                                                                                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type | POI 类型         | 例如：科教文化服务;学校;高等院校                                                                                                         |
| &nbsp;&nbsp;&nbsp;&nbsp;building | 楼信息列表         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | 建筑名称         | 例如：万达广场                                                                                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type | 类型             | 例如：科教文化服务;学校;高等院校                                                                                                         |
| &nbsp;&nbsp;&nbsp;&nbsp;streetNumber | 门牌信息列表     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;street | 街道名称         | 例如：中关村北二条                                                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;number | 门牌号           | 例如：3号                                                                                                                                |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 坐标点         | 经纬度坐标点：经度，纬度                                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;direction | 方向          | 坐标点所处街道方位                                                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 门牌地址到请求坐标的距离 | 单位：米                                                                                                                               |
| &nbsp;&nbsp;&nbsp;&nbsp;seaArea | 所属海域信息       | 例如：渤海                                                                                                                               |
| &nbsp;&nbsp;&nbsp;&nbsp;businessAreas | 经纬度所属商圈列表 |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;businessArea | 商圈信息     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 商圈中心点经纬度 |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | 商圈名称         | 例如：颐和园                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;id | 商圈所在区域的 adcode | 例如：朝阳区/海淀区                                                                                                                     |
| &nbsp;&nbsp;roads    | 道路信息列表           | 请求参数 extensions 为 all 时返回如下内容                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;road | 道路信息         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;id | 道路 id         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | 道路名称       |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 道路到请求坐标的距离 | 单位：米                                                                                                                               |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;direction | 方位        | 输入点和此路的相对方位                                                                                                                   |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 坐标点       |                                                                                                                                          |
| &nbsp;&nbsp;roadinters | 道路交叉口列表       | 请求参数 extensions 为 all 时返回如下内容                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;roadinter | 道路交叉口     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 交叉路口到请求坐标的距离 | 单位：米                                                                                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;direction | 方位        | 输入点相对路口的方位                                                                                                                     |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 路口经纬度   |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;first_id | 第一条道路 id |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;first_name | 第一条道路名称 |                                                                                                                                    |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;second_id | 第二条道路 id |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;second_name | 第二条道路名称 |                                                                                                                                    |
| &nbsp;&nbsp;pois     | poi 信息列表           | 请求参数 extensions 为 all 时返回如下内容                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;poi | poi 信息列表     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;id | poi 的 id         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | poi 点名称     |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type | poi 类型         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;tel | 电话             |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 该 POI 的中心点到请求坐标的距离 | 单位：米                                                                                                                           |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;direction | 方向        | 相对于输入点的方位                                                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;address | poi 地址信息 |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 坐标点       |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;businessarea | poi 所在商圈名称 |                                                                                                                                    |
| &nbsp;&nbsp;aois     | aoi 信息列表           | 请求参数 extensions 为 all 时返回如下内容                                                                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;aoi | aoi 信息         |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;id | 所属 aoi 的 id   |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;name | 所属 aoi 名称 |                                                                                                                                          |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;adcode | 所属 aoi 所在区域编码 |                                                                                                                                    |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;location | 所属 aoi 中心点坐标 |                                                                                                                                    |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;area | 所属 aoi 点面积 | 单位：平方米                                                                                                                             |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;distance | 输入经纬度是否在 aoi 面之中 | 0，代表在 aoi 内<br>其余整数代表距离 AOI 的距离                                                                                       |
| &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;type | 所属 aoi 类型 |                                                                                                                                          |

注意，部分返回值当返回值存在时，将以字符串类型返回；当返回值不存在时，则以数组类型返回。

## 地理编码匹配级别列表

| 匹配级别       | 示例                                       |
| -------------- | ------------------------------------------ |
| 国家           | 中国                                       |
| 省             | 河北省、北京市                             |
| 市             | 宁波市                                     |
| 区县           | 北京市朝阳区                               |
| 开发区         | 亦庄经济开发区                             |
| 乡镇           | 回龙观镇                                   |
| 村庄           | 三元村                                     |
| 热点商圈       | 上海市黄浦区老西门                         |
| 道路           | 北京市朝阳区阜通东大街                     |
| 道路交叉路口   | 北四环西路辅路/善缘街                       |
| 兴趣点         | 北京市朝阳区奥林匹克公园(南门)             |
| 门牌号         | 朝阳区阜通东大街6号                       |
| 单元号         | 望京西园四区5号楼2单元                     |
| 楼层           | 保留字段，建议兼容                         |
| 房间           | 保留字段，建议兼容                         |
| 公交地铁站点   | 海淀黄庄站 A1西北口                        |
| 门址（新增）   | 北京市朝阳区阜荣街10号                     |
| 小巷（新增）   | 保留字段，建议兼容                         |
| 住宅区（新增） | 广西壮族自治区柳州市鱼峰区德润路华润凯旋门 |
| 未知           | 未确认级别的 POI                           |
