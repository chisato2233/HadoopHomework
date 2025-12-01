package com.ecommerce.clean;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.NullWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * 日志清洗任务驱动类
 *
 * 用法: hadoop jar ecommerce-analysis.jar com.ecommerce.clean.LogCleanDriver <input> <output>
 */
public class LogCleanDriver extends Configured implements Tool {

    @Override
    public int run(String[] args) throws Exception {
        // 处理参数：可能包含类名作为第一个参数
        String inputPath;
        String outputPath;

        if (args.length == 2) {
            inputPath = args[0];
            outputPath = args[1];
        } else if (args.length == 3 && args[0].contains("LogCleanDriver")) {
            // 跳过类名参数
            inputPath = args[1];
            outputPath = args[2];
        } else {
            System.err.println("Usage: LogCleanDriver <input path> <output path>");
            System.err.println("Received " + args.length + " arguments");
            return -1;
        }

        Configuration conf = getConf();
        Job job = Job.getInstance(conf, "Log Clean Job");

        job.setJarByClass(LogCleanDriver.class);
        job.setMapperClass(LogCleanMapper.class);

        // 无 Reducer，Map-only 任务
        job.setNumReduceTasks(0);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(NullWritable.class);

        FileInputFormat.addInputPath(job, new Path(inputPath));
        FileOutputFormat.setOutputPath(job, new Path(outputPath));

        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        int exitCode = ToolRunner.run(new Configuration(), new LogCleanDriver(), args);
        System.exit(exitCode);
    }
}

