module.exports = function (context, eventHubMessages) {
    context.log(`[consumer-nodejs] Batch size ${eventHubMessages.length}`);
    var now = new Date().getTime();
    eventHubMessages.forEach((message, index) => {
        context.log(`[consumer-nodejs] EnqueuedTimeUtc = ${context.bindingData.enqueuedTimeUtcArray[index]}`);
        context.log(`[consumer-nodejs] Now = ${now}`);
        context.log(`[consumer-nodejs] Latency = ${now - context.bindingData.enqueuedTimeUtcArray[index]}`);
        context.log(`[consumer-nodejs] SequenceNumber = ${context.bindingData.sequenceNumberArray[index]}`);
        context.log(`[consumer-nodejs] Offset = ${context.bindingData.offsetArray[index]}`);
    });
    context.done();
};