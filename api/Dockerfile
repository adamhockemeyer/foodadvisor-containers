FROM node:14



WORKDIR /app
ADD ./package.json /app
ADD ./yarn.lock /app
RUN yarn install --frozen-lockfile

ADD . /app
RUN yarn seed

ENV STRAPI_ADMIN_CLIENT_URL https://frontend.whitecoast-27f7b316.eastus.azurecontainerapps.io
ENV NODE_ENV production

EXPOSE 1337

CMD ["yarn", "start"]
