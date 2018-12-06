const appInsights = require("applicationinsights");
appInsights.setup().start();
const client = appInsights.defaultClient;

module.exports = async function (context, eventHubMessages) {
    eventHubMessages.forEach((message, index) => {
        var enqueuedTimeUtc = new Date(context.bindingData.enqueuedTimeUtcArray[index]).getTime();
        var nowTimeUTC = new Date().getTime();
        client.trackMetric({name: "latency", value: (nowTimeUTC - enqueuedTimeUtc)});
        client.trackMetric({name: "batchSize", value: eventHubMessages.length});
        client.trackMetric({name: "stamp", value: process.env.WEBSITE_CURRENT_STAMPNAME});
        client.trackMetric({name: "host", value: process.env.COMPUTERNAME});
    });
    context.done();
};