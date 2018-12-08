const appInsights = require("applicationinsights");
appInsights.setup();
const client = appInsights.defaultClient;

module.exports = async function (context, eventHubMessages) {
    eventHubMessages.forEach((message, index) => {
        var enqueuedTimeUtc = new Date(context.bindingData.enqueuedTimeUtcArray[index]).getTime();
        var nowTimeUTC = new Date().getTime();
        // client.trackMetric({name: "offset", value: context.bindingData.offsetArray[index], tagOverrides:{"ai.operation.id": context.invocationId}});
        // client.trackMetric({name: "latency", value: (nowTimeUTC - enqueuedTimeUtc), tagOverrides:{"ai.operation.id": context.invocationId}});
        // client.trackMetric({name: "batchSize", value: eventHubMessages.length, tagOverrides:{"ai.operation.id": context.invocationId}});
        // client.trackMetric({name: "stamp", value: process.env.WEBSITE_CURRENT_STAMPNAME, tagOverrides:{"ai.operation.id": context.invocationId}});
        // client.trackMetric({name: "host", value: process.env.COMPUTERNAME, tagOverrides:{"ai.operation.id": context.invocationId}});
        client.trackMetric({name: "offset", value: context.bindingData.offsetArray[index]});
        client.trackMetric({name: "latency", value: (nowTimeUTC - enqueuedTimeUtc)});
        client.trackMetric({name: "batchSize", value: eventHubMessages.length});
        // client.trackMetric({name: "stamp", value: process.env.WEBSITE_CURRENT_STAMPNAME});
        // client.trackMetric({name: "host", value: process.env.COMPUTERNAME});
    });
};