const appInsights = require("applicationinsights");
appInsights.setup()
    .setAutoDependencyCorrelation(false)
    .setAutoCollectRequests(false)
    .setAutoCollectPerformance(false)
    .setAutoCollectExceptions(false)
    .setAutoCollectDependencies(false)
    .setAutoCollectConsole(false)
    .setUseDiskRetryCaching(true)
    .start();
const client = appInsights.defaultClient;

module.exports = async function (context, eventHubMessages) {
    total_latency = 0.0;
    eventHubMessages.forEach((message, index) => {
        var enqueuedTimeUtc = new Date(context.bindingData.enqueuedTimeUtcArray[index]).getTime();
        var nowTimeUTC = new Date().getTime();
        total_latency += (nowTimeUTC - enqueuedTimeUtc);
    });
    client.trackMetric({name: "batchAverageLatency", value:  (total_latency / eventHubMessages.length) / 1000.0});
    client.trackMetric({name: "batchSize", value: eventHubMessages.length});
};