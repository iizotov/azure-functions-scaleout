const appInsights = require("applicationinsights");
appInsights.setup()
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .start();
const client = appInsights.defaultClient;

module.exports = async function (context, eventHubMessages) {
    eventHubMessages.forEach((message, index) => {
        var enqueuedTimeUtc = new Date(context.bindingData.enqueuedTimeUtcArray[index]).getTime();
        var nowTimeUTC = new Date().getTime();
        client.trackMetric({name: "latency", value: (nowTimeUTC - enqueuedTimeUtc) / 1000.0});
        client.trackMetric({name: "batchSize", value: eventHubMessages.length});
    });
};