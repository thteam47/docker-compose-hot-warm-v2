# docker-compose-hot-warm

Build docker-compose 

```sh
docker-compose up -d
```

Nếu policy không được set tự động thì thực hiện run file sh.

```
sh setup/setupv2.sh
```

Nếu không thực hiện được file sh thì thực hiện put trên dev-tools của kibana.

### Access Elasticsearch 

http://localhost:9200

### Access Kibana

http://localhost:5601

#### Setup cluster - with Kibana

##### Index Lifecycle Management (ILM)

1. Thiết lập kiểm tra ILM

- Theo mặc đinh, thời gian kiểm tra ILM là 10 phút. Để thuận tiện việc demo thì thay đổi thời gian thành 5s để dễ theo dõi sự thay đổi của index giữa các node.

```
PUT _cluster/settings
{
  "persistent": {
    "indices.lifecycle.poll_interval": "5s",
    "slm.retention_schedule": "* * * * * ?"
  }
}
```

2. Thực hiện tạo policy

```
PUT /_ilm/policy/logs-hot-warm
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_age": "2m",
            "max_docs": 1000
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "2m",
        "actions": {
          "readonly" : { },
          "allocate" : {
            "number_of_replicas" : 0,
            "include" : {
              "size" : "warm"
            }
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "shrink": {
            "number_of_shards": 1
          },
          "set_priority": {
            "priority": 50
          }
        }
      },
      "cold": {
        "min_age": "5m",
        "actions": {
          "allocate" : {
            "number_of_replicas" : 0,
            "include" : {
              "size" : "cold"
            }
          },
          "set_priority": {
            "priority": 0
          },
          "searchable_snapshot": {
            "snapshot_repository": "logs-snapshots-repository"
          }
        }
      },
      "delete": {
        "min_age": "7m",
        "actions": {
          "wait_for_snapshot": {
            "policy": "logs-snapshot-policy"
          },
          "delete": {}
        }
      }
    }
  }
}
```

* Tạo policy logs-hot-warm. 

	* Hot: Index đang được cập nhật và truy vấn.
	* Warm: Index không được cập nhật nhưng vẫn được truy vấn.
	* Cold: Index không được cập nhật, các truy vấn không thường xuyên. Tốc độ truy vấn chậm hơn. 
	* Frozen: Index không được cập nhật, hiếm khi được truy vấn. Tốc độ truy vấn cực kỳ châm. 
	* Delete: Index không cần thiết và được xóa.


* Để thuận tiện cho viêc demo nên ta tối thiểu thời gian:

	* Thời gian tồn tại ở hot là 7 ngày → 2 phút.
	* Chuyển từ hot sang warm sau 7 ngày → sau 2 phút.
	* Di chuyển từ warm sang cold sau 1 thang → sau 5 phút.
	* Sau 2 tháng thì ghi lai shapshot và xóa → sau 7 phút.

* Các thuộc tính của policy:
	* Rollover:
		* max_age: thời gian tối đa tồn tại kể từ khi tạo index.
		* max_docs: số documents tối đa của index, không tinh ở các bản replicas.
		* max_size: kích thước tối đa của index, là tổng kích thước các shards của index, không tính trên các bản sao.
		* max_primary_shard_size: kich thước tối dad của shard chính.
		* min_age: thời gian tối thiểu đê bắt đầu chuyển index.
	* Priority: độ ưu tiên, độ ưu tiên càng lớn thì được thực hiện trước.

3. Tạo template cho index

```
PUT _template/template_logs
{
  "index_patterns": ["testlog-*"],
  "settings": {
    "index.number_of_shards" : 2,
    "index.number_of_replicas" : 1,
    "lifecycle.name": "logs-hot-warm",
    "lifecycle.rollover_alias": "test-logs"   
  },
  "mappings": {
    "properties" : {
      "name": {
        "type": "text",
        "fields": {
          "keyword": {
            "type": "keyword",
            "ignore_above": 256
          }
        }
      },
      "age":{
          "type":"long"
      }
    }
  }
}
```

4.  Khởi tạo index

```
PUT testlog -000001
{
  "aliases": {
    "test-logs":{
      "is_write_index": true
    }
  }
}
```

##### Snapshot Lifecycle Management (SLM)

1. Tạo snapshot repository

```
PUT _snapshot/logs-snapshots-repository
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/snapshots"
  }
}
```

* Snapshot repository là nơi chứa các snapshot được ghi lại sau khi qua cold. Các shapshot được lưu lại và có thể khôi phục được dữ liệu.
* Nếu không put đuợc snapshot repository thì kiểm tra thiết lập lại xem các node đã có path.repo chưa, nếu chưa thi cập nhật. Sau đó tao đuơng dẫn với command:

	```
	docker exec -it elasticsearch-hot /bin/bash
	mkdir /usr/share/elasticsearch/snapshots/
	chown -R elasticsearch:elasticsearch /usr/share/elasticsearch/snapshots/
	```
	* Trong đó `/usr/share/elasticsearch/snapshots/` là đuờng dẫn snapshot repository.

2. Lập lịch tạo snapshot

```
PUT _slm/policy/logs-snapshot-policy
{
  "schedule": "0 0/10 * * * ?",
  "name": "<logs_snapshot_{now{yyyy-MM-dd_HH:mm}}>",
  "repository": "logs-snapshots-repository",
  "config": {
    "indices": ["*"],
    "include_global_state": true
  },
  "retention": {
    "expire_after": "30m",
    "max_count": 5,
    "min_count": 2
  }
}
```
* Các thuộc tính:
	*  [schedule](https://www.elastic.co/guide/en/elasticsearch/reference/current/api-conventions.html#api-cron-expressions "schedule"): để thuận tiện cho demo nên với thiết lập trên thì sẽ tạo snapshot sau mỗi 10 phút. 
		* 0 0/15 9 * * ?
		Trigger every 15 minutes starting at 9:00 a.m. UTC and ending at 9:45 a.m. UTC every day.
	* include_global_state: If true, include the cluster state in the snapshot. Defaults to true.
	* retention: giữ snapshot 30 ngày, giữ ít nhất 2 snapshot kể cả khi chúng quá 30 ngày  và nhiều nhất 5 snapshot kể cả khi quá 30 ngày.

#### Watch the generations - Kibana line
- Xem các roles trên node.
	* m: master node
	* s: content tier
	* h: hot data tier
	* w: warm data tier
	* c: cold data tier
	* f: frozen data tier

```
GET _cat/nodes?v&h=name,node.role&s=name
```

```
// kiểm tra node
GET _cat/nodeattrs?v&h=node,attr,value&s=attr:desc
GET _cat/thread_pool/search_throttled?v&h=node_name,name,active,rejected,queue,completed&s=node_name
// kiểm tra index trên node
GET _cat/shards/testlog-000001?v&h=index,shard,prirep,node&s=node
// xem chi tiết index
GET .testlog-*/_ilm/explain
GET testlog-000001/_ilm/explain
GET /_cat/indices?v
GET _cat/indices/testlog-000001?v&h=health,status,index,pri,rep,docs.count,store.size
```




