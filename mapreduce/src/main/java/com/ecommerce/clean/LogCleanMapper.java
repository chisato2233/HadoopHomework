package com.ecommerce.clean;

import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.NullWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Mapper;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * 日志清洗 Mapper
 *
 * 清洗规则：
 * 1. 字段数量必须为5个
 * 2. action_type 仅允许: click, browse, cart, order
 * 3. duration 必须 >= 0
 * 4. user_id 不能为空
 */
public class LogCleanMapper extends Mapper<LongWritable, Text, Text, NullWritable> {

    private static final Set<String> VALID_ACTIONS = new HashSet<>(
            Arrays.asList("click", "browse", "cart", "order")
    );

    private Text outputKey = new Text();

    @Override
    protected void map(LongWritable key, Text value, Context context)
            throws IOException, InterruptedException {

        String line = value.toString().trim();

        // 跳过注释行
        if (line.startsWith("#") || line.isEmpty()) {
            return;
        }

        String[] fields = line.split(",");

        // 规则1: 字段数量检查
        if (fields.length != 5) {
            context.getCounter("CleanStats", "InvalidFieldCount").increment(1);
            return;
        }

        String userId = fields[0].trim();
        String productId = fields[1].trim();
        String actionType = fields[2].trim();
        String durationStr = fields[3].trim();
        String eventTime = fields[4].trim();

        // 规则4: user_id 不能为空
        if (userId.isEmpty()) {
            context.getCounter("CleanStats", "EmptyUserId").increment(1);
            return;
        }

        // 规则2: action_type 验证
        if (!VALID_ACTIONS.contains(actionType)) {
            context.getCounter("CleanStats", "InvalidActionType").increment(1);
            return;
        }

        // 规则3: duration 验证
        try {
            int duration = Integer.parseInt(durationStr);
            if (duration < 0) {
                context.getCounter("CleanStats", "NegativeDuration").increment(1);
                return;
            }
        } catch (NumberFormatException e) {
            context.getCounter("CleanStats", "InvalidDuration").increment(1);
            return;
        }

        // 输出清洗后的数据
        outputKey.set(line);
        context.write(outputKey, NullWritable.get());
        context.getCounter("CleanStats", "ValidRecords").increment(1);
    }
}

