#!/system/bin/sh
# 注意：Android 上通常使用 #!/system/bin/sh 而不是 #!bin/sh

MODDIR=${0%/*}
if [ -f "$MODDIR/disable" ]; then
	exit 0
fi

# 预加载配置，减少重复 IO (可选优化，此处保持原逻辑结构以便阅读)
config_conf="$(cat "$MODDIR/config.conf" 2>/dev/null | grep -v '^#')"

# 数据库路径常量
R_ED=1 
UN_R=0 

# 辅助函数：安全获取配置项
get_config() {
    local key=$1
    local default=$2
    local val=$(echo "$config_conf" | grep "^${key}=" | head -n1 | cut -d'=' -f2-)
    if [ -z "$val" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

bark_push() {
	local cell=$1
	local msg_date=$2
	local body=$3
	local MF_app=$4
	
	# 处理换行符，防止破坏 JSON 结构
	local wx_text=$(printf '%s' "$body" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r//g')
	
	local bark_url=$(get_config "bark_url" "")
	local device_key=$(get_config "device_key" "")
	
	if [ -z "$bark_url" ] || [ -z "$device_key" ]; then
		echo "$(date +%F_%T) 【Bark】配置缺失，跳过发送。" >> "$MODDIR/log.log"
		return 1
	fi

	local bark_post="{\"title\": \"$MF_app\", \"body\": \"$cell:$wx_text\",\"level\": \"active\",\"volume\": 5,\"badge\": 1,\"device_key\": \"$device_key\",\"subtitle\":\"[$msg_date]\",\"group\": \"$MF_app\"}"
	
	local bark_push=$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$bark_post" "$bark_url")
	
	if [ -n "$bark_push" ]; then
		# 提取 code，兼容不同格式的 JSON
		local bark_push_errcode=$(echo "$bark_push" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
		if [ "$bark_push_errcode" = "200" ]; then
			echo "$(date +%F_%T) 【Bark通道 发送成功】：$cell" >> "$MODDIR/log.log"
		else
			echo "$(date +%F_%T) 【Bark通道 发送失败】：Code:$bark_push_errcode, Raw:$bark_push" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【Bark通道 发送失败】：curl 无返回" >> "$MODDIR/log.log"
	fi
}

winxin_push(){
	local content=$1
	# 转义双引号、反斜杠，再处理换行，防止破坏 JSON 结构
	content=$(printf '%s' "$content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/\r/\\r/g')
	
	local webhook=$(get_config "wx_webhook" "")
	if [ -z "$webhook" ]; then
		echo "$(date +%F_%T) 【WeChat】配置缺失，跳过发送。" >> "$MODDIR/log.log"
		return 1
	fi

	local web_post="{\"msgtype\": \"text\",\"text\": {\"content\":\"$content\",\"mentioned_list\":[\"@all\"]}}"
	local web_push=$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$web_post" "$webhook")
	
	if [ -n "$web_push" ]; then
		local errcode=$(echo "$web_push" | grep -o '"errcode"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
		if [ "$errcode" = "0" ]; then
			echo "$(date +%F_%T) 【微信群机器人通道 发送成功】" >> "$MODDIR/log.log"
		else
			echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：Err:$errcode, Raw:$web_push" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【微信群机器人通道 发送失败】：curl 无返回" >> "$MODDIR/log.log"
	fi
}

wx_pusher(){
	local content=$1
	# WxPusher 支持 HTML，但也需要转义部分字符，这里简化处理，假设传入的是已处理的 HTML 片段
	# 注意：如果 content 包含双引号，可能会破坏 JSON，建议在此处做更严格的转义，或者使用 jq (如果可用)
	# 这里使用 sed 简单转义双引号
	content=$(echo "$content" | sed 's/"/\\"/g')
	
	local appToken=$(get_config "wxpusher_token" "")
	local topicId=$(get_config "wxpusher_topic" "39910")
	
	if [ -z "$appToken" ]; then
		echo "$(date +%F_%T) 【WxPusher】Token 缺失，跳过发送。" >> "$MODDIR/log.log"
		return 1
	fi
	
	local json_data="{\"appToken\": \"$appToken\", \"content\": \"$content\", \"contentType\": 2, \"summary\": \"短信/电话通知\", \"topicIds\": [\"$topicId\"], \"verifyPayType\": 0}"
	
	local web_push=$(curl -s --connect-timeout 12 -m 15 -H 'Content-Type: application/json' -d "$json_data" "https://wxpusher.zjiecode.com/api/send/message")
	
	if [ -n "$web_push" ]; then
		local code=$(echo "$web_push" | grep -o '"code"[[:space:]]*:[[:space:]]*[0-9]*' | grep -o '[0-9]*')
		if [ "$code" = "1000" ]; then
			echo "$(date +%F_%T) 【WxPusher通道 发送成功】" >> "$MODDIR/log.log"
		else
			local error_msg=$(echo "$web_push" | grep -o '"msg"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/')
			echo "$(date +%F_%T) 【WxPusher通道 发送失败】：$error_msg" >> "$MODDIR/log.log"
		fi
	else
		echo "$(date +%F_%T) 【WxPusher通道 发送失败】：curl 无返回" >> "$MODDIR/log.log"
	fi
}

forwarding(){
    local startTime=$(get_config "startTime" "2025-04-22")
    local MSG_DB_PATH=$(get_config "msg_db_path" "")
    
    if [ ! -f "$MSG_DB_PATH" ]; then
        return 0
    fi

    # 优化：移除 bc 依赖，使用 shell 算术运算
    # 注意：sqlite3 的 DATETIME 处理可能需要根据具体 Android 版本调整，这里保留原逻辑但修复 bc
    sqlite3 -separator $'\t' "$MSG_DB_PATH" "SELECT _id, address, strftime('%Y-%m-%d %H:%M:%S', date/1000, 'unixepoch', 'localtime'), body, sim_id FROM sms WHERE type = 1 AND read = 0 AND datetime(date/1000, 'unixepoch', 'localtime') > '$startTime' LIMIT 1;" | while IFS=$'\t' read -r sms_id address formatted_date body sim_id; do
        if [ -z "$sms_id" ]; then continue; fi

        local sim1_name=$(get_config "sim1_name" "")
        local sim2_name=$(get_config "sim2_name" "")
        local sim1_simid=$(get_config "sim1_simid" "")
        local sim2_simid=$(get_config "sim2_simid" "")
        local sim_slot
        if [ -n "$sim1_simid" ] && [ "$sim_id" = "$sim1_simid" ]; then
            sim_slot="${sim1_name:-SIM1(simid=$sim_id)}"
        elif [ -n "$sim2_simid" ] && [ "$sim_id" = "$sim2_simid" ]; then
            sim_slot="${sim2_name:-SIM2(simid=$sim_id)}"
        else
            sim_slot="SIM(simid=$sim_id)"
        fi

        local bark_switch=$(get_config "bark_switch" "0")
        local wx_switch=$(get_config "wx_switch" "0")
        local wxpusher_switch=$(get_config "wxpusher" "0")
        local has_action=0

        if [ "$bark_switch" != "0" ]; then
            bark_push "$address" "$formatted_date" "$body" "短信[$sim_slot]"
            has_action=1
        fi
        
        if [ "$wx_switch" != "0" ]; then
            local content="$(printf '类型：未读短信\n卡槽：%s\n号码：%s\n时间：%s\n内容：\n\n%s' "$sim_slot" "$address" "$formatted_date" "$body")"
            winxin_push "$content"
            has_action=1
        fi
        
        if [ "$wxpusher_switch" != "0" ]; then
            # 简单的 HTML 转义
            local safe_body=$(echo "$body" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
                        # 替代方案：使用 div 配合样式，兼容性通常更好
            local html_content="<h3>未读短信通知</h3><p><strong>号码：</strong>$address</p><p><strong>时间：</strong>$formatted_date</p><p><strong>内容：</strong></p><div style=\"white-space: pre-wrap; word-break: break-all; background:#f5f5f5; padding:10px; border-radius:5px;\">$safe_body</div>"
            wx_pusher "$html_content"
            has_action=1
        fi
        
        if [ "$has_action" = "1" ]; then
            sqlite3 "$MSG_DB_PATH" "UPDATE sms SET read = $R_ED WHERE _id = $sms_id;"
        fi
    done
}

callReport(){
    local startTime=$(get_config "startTime" "2025-04-22")
    local CALL_DB_PATH=$(get_config "call_db_path" "")
    
    if [ ! -f "$CALL_DB_PATH" ]; then
        return 0
    fi

    sqlite3 -separator $'\t' "$CALL_DB_PATH" "SELECT _id, number, strftime('%Y-%m-%d %H:%M:%S', date/1000, 'unixepoch', 'localtime'), new, simid FROM calls WHERE type = 3 AND new = 1 AND datetime(date/1000, 'unixepoch', 'localtime') > '$startTime' LIMIT 1;" | while IFS=$'\t' read -r call_id number formatted_date is_new simid; do
        if [ -z "$call_id" ]; then continue; fi

        local sim1_name=$(get_config "sim1_name" "")
        local sim2_name=$(get_config "sim2_name" "")
        local sim1_simid=$(get_config "sim1_simid" "")
        local sim2_simid=$(get_config "sim2_simid" "")
        local sim_slot
        if [ -n "$sim1_simid" ] && [ "$simid" = "$sim1_simid" ]; then
            sim_slot="${sim1_name:-SIM1(simid=$simid)}"
        elif [ -n "$sim2_simid" ] && [ "$simid" = "$sim2_simid" ]; then
            sim_slot="${sim2_name:-SIM2(simid=$simid)}"
        else
            sim_slot="SIM(simid=$simid)"
        fi

        local bark_switch=$(get_config "bark_switch" "0")
        local wx_switch=$(get_config "wx_switch" "0")
        local wxpusher_switch=$(get_config "wxpusher" "0")
        local has_action=0

        if [ "$bark_switch" != "0" ]; then
            bark_push "$number" "$formatted_date" "未接来电" "电话[$sim_slot]"
            has_action=1
        fi
        
        if [ "$wx_switch" != "0" ]; then
            local content="$(printf '类型：未接来电\n卡槽：%s\n号码：%s\n时间：%s' "$sim_slot" "$number" "$formatted_date")"
            winxin_push "$content"
            has_action=1
        fi
        
        if [ "$wxpusher_switch" != "0" ]; then
            local html_content="<h3>未接来电通知</h3><p><strong>号码：</strong>$number</p><p><strong>时间：</strong>$formatted_date</p>"
            wx_pusher "$html_content"
            has_action=1
        fi
        
        if [ "$has_action" = "1" ]; then
            sqlite3 "$CALL_DB_PATH" "UPDATE calls SET new = 0 WHERE _id = $call_id;"
        fi
    done
}

# 执行主逻辑
forwarding
callReport
