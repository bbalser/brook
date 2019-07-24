use Mix.Config

config :brook,
  divo: [
    {DivoKafka, [create_topics: "test:1:1", auto_topic: false]},
    DivoRedis
  ],
  divo_wait: [dwell: 700, max_tries: 50]
