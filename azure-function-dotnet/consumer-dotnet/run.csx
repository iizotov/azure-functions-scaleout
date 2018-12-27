#r "../bin/Microsoft.Azure.EventHubs.dll"
#r "../bin/Microsoft.ApplicationInsights.dll"

using System;
using Microsoft.Azure.EventHubs;
using Microsoft.ApplicationInsights;

private static TelemetryClient client = new TelemetryClient() { };

public static async Task Run(EventData[] messageBatch, ILogger log)
{
    double totalLatency = 0.0;
    client.Context.Properties["experiment"] = Environment.GetEnvironmentVariable("EXPERIMENT", EnvironmentVariableTarget.Process);
    foreach (EventData message in messageBatch)
    {
        DateTime nowTimeUTC = DateTime.UtcNow;
        DateTime enqueuedTimeUtc = message.SystemProperties.EnqueuedTimeUtc;
        totalLatency += (nowTimeUTC - enqueuedTimeUtc).TotalMilliseconds;
    }
    client.TrackMetric("batchSize", messageBatch.Length);
    client.TrackMetric("batchAverageLatency", (totalLatency / messageBatch.Length) / 1000.0);
}