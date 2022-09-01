FROM node:14

WORKDIR /app
ADD ./package.json /app
ADD ./yarn.lock /app
RUN yarn install --frozen-lockfile

ADD . /app
RUN sqlite3 /volumes/azurefiles/data.db 'PRAGMA journal_mode=WAL;'
RUN yarn seed


RUN yarn build

EXPOSE 1337

CMD ["yarn", "start"]
