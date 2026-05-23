FROM ruby:3.4-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 4001

CMD ["bundle", "exec", "ruby", "app.rb"]
