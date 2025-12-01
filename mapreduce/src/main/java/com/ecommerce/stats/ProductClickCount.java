package com.ecommerce.stats;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

import java.io.IOException;

/**
 * 商品点击量统计
 *
 * 输入: 清洗后的用户行为日志
 * 输出: product_id \t click_count
 *
 * 优化: 使用 Combiner 减少 Shuffle 数据量
 */
public class ProductClickCount extends Configured implements Tool {

    /**
     * Mapper: 提取点击行为，输出 <product_id, 1>
     */
    public static class ClickMapper extends Mapper<LongWritable, Text, Text, IntWritable> {

        private static final IntWritable ONE = new IntWritable(1);
        private Text productId = new Text();

        @Override
        protected void map(LongWritable key, Text value, Context context)
                throws IOException, InterruptedException {

            String[] fields = value.toString().split(",");
            if (fields.length >= 3) {
                String actionType = fields[2].trim();
                if ("click".equals(actionType)) {
                    productId.set(fields[1].trim());
                    context.write(productId, ONE);
                }
            }
        }
    }

    /**
     * Combiner & Reducer: 累加点击次数
     */
    public static class SumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {

        private IntWritable result = new IntWritable();

        @Override
        protected void reduce(Text key, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {

            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Usage: ProductClickCount <input> <output>");
            return -1;
        }

        Configuration conf = getConf();
        Job job = Job.getInstance(conf, "Product Click Count");

        job.setJarByClass(ProductClickCount.class);
        job.setMapperClass(ClickMapper.class);
        job.setCombinerClass(SumReducer.class);  // 使用 Combiner 优化
        job.setReducerClass(SumReducer.class);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new ProductClickCount(), args);
        System.exit(exitCode);
    }
}

