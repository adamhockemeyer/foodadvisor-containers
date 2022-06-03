let appInsights = require('applicationinsights');


module.exports = () => {
    let isConfigured = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

    if (isConfigured) {
        appInsights.setup()
            .setAutoDependencyCorrelation(true)
            .setAutoCollectRequests(true)
            .setAutoCollectPerformance(true, true)
            .setAutoCollectExceptions(true)
            .setAutoCollectDependencies(true)
            .setAutoCollectConsole(true)
            .setUseDiskRetryCaching(true)
            .setSendLiveMetrics(true)
            .start();

        appInsights.defaultClient.trackTrace({
            message: 'STRAPI: trace on init'
        });

        console.log('App Insights Setup');
    }
    else {
        console.warn('Please set environment variable: APPLICATIONINSIGHTS_CONNECTION_STRING, if you would like to enable Azure application insights.');
    }

    return async (ctx, next) => {
        let client = appInsights.defaultClient;

        await next();

        if (isConfigured) {
            appInsights.defaultClient.trackNodeHttpRequest({
                request: ctx.req,
                response: ctx.res
            });
        }
    }
};

